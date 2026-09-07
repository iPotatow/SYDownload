#if canImport(SwiftUI)
import Foundation
import XDownloaderCore

struct BridgeClient: Sendable {
    enum BridgeError: LocalizedError, Sendable {
        case bridgeNotFound
        case malformedResponse
        case processFailed(String)

        var errorDescription: String? {
            switch self {
            case .bridgeNotFound:
                return "找不到 Python Bridge。请通过 script/build_and_run.sh 启动，或设置 XDOWNLOADER_BRIDGE。"
            case .malformedResponse:
                return "Python Bridge 返回了无法解析的数据。"
            case .processFailed(let message):
                return message
            }
        }
    }

    func send(_ request: BridgeRequest) async throws -> BridgeResponse {
        let bridgeURL = try resolveBridgeURL()
        let payload = try JSONEncoder().encode(request)

        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3", bridgeURL.path, "--once"]
            process.standardOutput = stdout
            process.standardError = stderr
            process.standardInput = Pipe()

            guard let stdin = process.standardInput as? Pipe else {
                throw BridgeError.processFailed("无法建立 Bridge 输入管道。")
            }

            try process.run()
            stdin.fileHandleForWriting.write(payload + Data("\n".utf8))
            try? stdin.fileHandleForWriting.close()

            let output = stdout.fileHandleForReading.readDataToEndOfFile()
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let message = String(decoding: errorData, as: UTF8.self)
                throw BridgeError.processFailed(message.isEmpty ? "Bridge 进程失败。" : message)
            }

            guard let line = String(decoding: output, as: UTF8.self)
                .split(separator: "\n")
                .last,
                let data = String(line).data(using: .utf8)
            else {
                throw BridgeError.malformedResponse
            }
            return try JSONDecoder().decode(BridgeResponse.self, from: data)
        }.value
    }

    private func resolveBridgeURL() throws -> URL {
        if let override = ProcessInfo.processInfo.environment["XDOWNLOADER_BRIDGE"] {
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
}

#endif
