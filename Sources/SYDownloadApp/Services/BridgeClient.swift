#if canImport(SwiftUI)
import Foundation
import SYDownloadCore

struct BridgeClient: Sendable {
    enum BridgeError: LocalizedError, Sendable {
        case bridgeNotFound
        case pythonNotFound
        case malformedResponse
        case timedOut
        case cancelled
        case processFailed(String)

        var errorDescription: String? {
            switch self {
            case .bridgeNotFound:
                return "找不到 Python Bridge。"
            case .pythonNotFound:
                return "找不到内置 Python，也没有可用的开发环境 Python。"
            case .malformedResponse:
                return "Python Bridge 返回了无法解析的数据。"
            case .timedOut:
                return "下载任务超时。"
            case .cancelled:
                return "下载任务已取消。"
            case .processFailed(let message):
                return message
            }
        }
    }

    func send(_ request: BridgeRequest) async throws -> BridgeResponse {
        try await sendStreaming(request) { _ in }
    }

    func sendStreaming(
        _ request: BridgeRequest,
        onProgress: @escaping @Sendable (BridgeProgressEvent) -> Void
    ) async throws -> BridgeResponse {
        let bridgeURL = try resolveBridgeURL()
        let python = try resolvePython()
        let payload = try JSONEncoder().encode(request)
        let managed = ManagedBridgeProcess()
        let registry = BridgeProcessRegistry.shared
        await registry.register(managed, for: request.id)

        let timeoutSeconds = max(
            1,
            request.timeoutSeconds ?? (request.command == "download" ? 15 * 60 : 60)
        )
        do {
            let result = try await runWithTimeout(
                request: request,
                bridgeURL: bridgeURL,
                python: python,
                payload: payload,
                managed: managed,
                timeoutSeconds: timeoutSeconds,
                onProgress: onProgress
            )
            await registry.unregister(request.id)
            return result
        } catch is CancellationError {
            managed.cancel()
            await registry.unregister(request.id)
            throw BridgeError.cancelled
        } catch {
            await registry.unregister(request.id)
            throw error
        }
    }

    static func cancel(requestID: UUID) async {
        await BridgeProcessRegistry.shared.cancel(requestID)
    }

    private func runWithTimeout(
        request: BridgeRequest,
        bridgeURL: URL,
        python: PythonLaunch,
        payload: Data,
        managed: ManagedBridgeProcess,
        timeoutSeconds: Double,
        onProgress: @escaping @Sendable (BridgeProgressEvent) -> Void
    ) async throws -> BridgeResponse {
        try await withThrowingTaskGroup(of: BridgeResponse.self) { group in
            group.addTask {
                try await runProcess(
                    request: request,
                    bridgeURL: bridgeURL,
                    python: python,
                    payload: payload,
                    managed: managed,
                    onProgress: onProgress
                )
            }
            group.addTask {
                try await Task.sleep(for: .seconds(timeoutSeconds))
                try Task.checkCancellation()
                throw BridgeError.timedOut
            }

            do {
                guard let first = try await group.next() else {
                    throw BridgeError.malformedResponse
                }
                group.cancelAll()
                return first
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }

    private func runProcess(
        request: BridgeRequest,
        bridgeURL: URL,
        python: PythonLaunch,
        payload: Data,
        managed: ManagedBridgeProcess,
        onProgress: @escaping @Sendable (BridgeProgressEvent) -> Void
    ) async throws -> BridgeResponse {
        let worker = Task.detached(priority: .userInitiated) {
            try runProcessSynchronously(
                request: request,
                bridgeURL: bridgeURL,
                python: python,
                payload: payload,
                managed: managed,
                onProgress: onProgress
            )
        }

        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            managed.cancel()
            worker.cancel()
        }
    }

    private func runProcessSynchronously(
        request: BridgeRequest,
        bridgeURL: URL,
        python: PythonLaunch,
        payload: Data,
        managed: ManagedBridgeProcess,
        onProgress: @escaping @Sendable (BridgeProgressEvent) -> Void
    ) throws -> BridgeResponse {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let stdin = Pipe()

        process.executableURL = python.executable
        process.arguments = python.argumentsPrefix + [bridgeURL.path, "--once"]
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = stdin

        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        environment["PYTHONNOUSERSITE"] = "1"
        if let resources = Bundle.main.resourceURL?.path {
            environment["SYDOWNLOAD_BUNDLE_RESOURCES"] = resources
        }
        process.environment = environment

        try process.run()
        managed.attach(process)
        stdin.fileHandleForWriting.write(payload + Data("\n".utf8))
        try? stdin.fileHandleForWriting.close()

        var buffer = Data()
        var finalResponse: BridgeResponse?
        let decoder = JSONDecoder()

        func consume(_ lineData: Data) {
            guard !lineData.isEmpty else { return }
            if let event = try? decoder.decode(BridgeProgressEvent.self, from: lineData),
               event.event == "progress" {
                onProgress(event)
                return
            }
            if let response = try? decoder.decode(BridgeResponse.self, from: lineData) {
                finalResponse = response
            }
        }

        while true {
            let chunk = stdout.fileHandleForReading.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer.subdata(in: buffer.startIndex..<newline)
                buffer.removeSubrange(buffer.startIndex...newline)
                consume(lineData)
            }
        }
        if !buffer.isEmpty {
            consume(buffer)
        }

        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if managed.wasCancelled {
            throw BridgeError.cancelled
        }
        guard process.terminationStatus == 0 else {
            let message = String(decoding: errorData, as: UTF8.self)
            throw BridgeError.processFailed(
                message.isEmpty ? "Bridge 进程失败（退出码 \(process.terminationStatus)）。" : message
            )
        }
        guard let finalResponse else {
            throw BridgeError.malformedResponse
        }
        return finalResponse
    }

    private func resolveBridgeURL() throws -> URL {
        if let override = ProcessInfo.processInfo.environment["SYDOWNLOAD_BRIDGE"] {
            let url = URL(fileURLWithPath: override)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }

        if let resource = Bundle.main.resourceURL?
            .appendingPathComponent("bridge/engine_bridge.py"),
           FileManager.default.fileExists(atPath: resource.path) {
            return resource
        }

        let dev = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Bridge/engine_bridge.py")
        if FileManager.default.fileExists(atPath: dev.path) { return dev }
        throw BridgeError.bridgeNotFound
    }

    private func resolvePython() throws -> PythonLaunch {
        if let override = ProcessInfo.processInfo.environment["SYDOWNLOAD_PYTHON"] {
            let url = URL(fileURLWithPath: override)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return PythonLaunch(executable: url, argumentsPrefix: [])
            }
        }

        if let bundled = Bundle.main.resourceURL?
            .appendingPathComponent("python/bin/python3"),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return PythonLaunch(executable: bundled, argumentsPrefix: [])
        }

        let env = URL(fileURLWithPath: "/usr/bin/env")
        guard FileManager.default.isExecutableFile(atPath: env.path) else {
            throw BridgeError.pythonNotFound
        }
        return PythonLaunch(executable: env, argumentsPrefix: ["python3"])
    }
}

private struct PythonLaunch: Sendable {
    let executable: URL
    let argumentsPrefix: [String]
}

private final class ManagedBridgeProcess: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    var wasCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func attach(_ process: Process) {
        lock.lock()
        self.process = process
        let shouldCancel = cancelled
        lock.unlock()
        if shouldCancel, process.isRunning {
            process.terminate()
        }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let process = self.process
        lock.unlock()
        if let process, process.isRunning {
            process.terminate()
        }
    }
}

private actor BridgeProcessRegistry {
    static let shared = BridgeProcessRegistry()
    private var processes: [UUID: ManagedBridgeProcess] = [:]

    func register(_ process: ManagedBridgeProcess, for id: UUID) {
        processes[id] = process
    }

    func unregister(_ id: UUID) {
        processes.removeValue(forKey: id)
    }

    func cancel(_ id: UUID) {
        processes[id]?.cancel()
    }
}

#endif
