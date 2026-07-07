import Foundation
import XCTest
@testable import SYDownloadApp
import SYDownloadCore

private actor ParallelDownloadProbe {
    private var activeDownloads = 0
    private(set) var maxActiveDownloads = 0
    private(set) var downloadRequests = 0
    let delay: Duration

    init(delay: Duration = .milliseconds(100)) {
        self.delay = delay
    }

    func send(_ request: BridgeRequest) async throws -> BridgeResponse {
        BridgeResponse(
            id: request.id,
            ok: true,
            platform: PlatformDetector.detect(request.url ?? ""),
            message: "ok",
            details: [:]
        )
    }

    func stream(
        _ request: BridgeRequest,
        onProgress: @escaping @Sendable (BridgeProgressEvent) -> Void
    ) async throws -> BridgeResponse {
        guard request.command == "download" else { return try await send(request) }
        activeDownloads += 1
        downloadRequests += 1
        maxActiveDownloads = max(maxActiveDownloads, activeDownloads)
        defer { activeDownloads -= 1 }

        onProgress(
            BridgeProgressEvent(
                id: request.id,
                message: "正在写入下载文件…",
                progress: 0.42,
                bytesWritten: 4096,
                fileCount: 1
            )
        )
        try await Task.sleep(for: delay)
        return BridgeResponse(
            id: request.id,
            ok: true,
            platform: PlatformDetector.detect(request.url ?? ""),
            message: "下载完成并已验证文件。",
            details: [
                "verification": "written",
                "verified_files": "1",
                "verified_bytes": "4096",
            ]
        )
    }
}

@MainActor
final class DownloadRuntimeTests: XCTestCase {
    private func makeDefaults(_ name: String = #function) -> (UserDefaults, String) {
        let suite = "SYDownload.DownloadRuntimeTests.\(name).\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    func testBatchUsesThreeWayConcurrencyAndStreamsRealProgress() async {
        let probe = ParallelDownloadProbe(delay: .milliseconds(120))
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(
            userDefaults: defaults,
            bridgeStreamingSend: { request, progress in
                try await probe.stream(request, onProgress: progress)
            },
            bridgeSend: { request in
                try await probe.send(request)
            }
        )
        model.input = (0..<7)
            .map { "https://xhslink.com/concurrent-\($0)" }
            .joined(separator: "\n")

        let run = Task { await model.runDownload() }
        var sawProgress = false
        for _ in 0..<200 {
            if model.tasks.contains(where: { $0.progress == 0.42 && $0.bytesWritten == 4096 }) {
                sawProgress = true
                break
            }
            try? await Task.sleep(for: .milliseconds(5))
        }
        await run.value

        let maxActiveDownloads = await probe.maxActiveDownloads
        let downloadRequests = await probe.downloadRequests
        XCTAssertTrue(sawProgress)
        XCTAssertEqual(maxActiveDownloads, 3)
        XCTAssertEqual(downloadRequests, 7)
        XCTAssertEqual(model.tasks.filter { $0.state == .completed }.count, 7)
        XCTAssertEqual(model.history.count, 7)
    }

    func testQueuedTaskCanBeCancelledBeforeBridgeStarts() async {
        let probe = ParallelDownloadProbe(delay: .milliseconds(180))
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(
            userDefaults: defaults,
            bridgeStreamingSend: { request, progress in
                try await probe.stream(request, onProgress: progress)
            },
            bridgeSend: { request in
                try await probe.send(request)
            }
        )
        model.input = (0..<4)
            .map { "https://xhslink.com/cancel-\($0)" }
            .joined(separator: "\n")

        let run = Task { await model.runDownload() }
        var queuedID: UUID?
        for _ in 0..<200 {
            if model.tasks.count == 4,
               model.tasks.filter({ $0.state == .downloading }).count == 3,
               let queued = model.tasks.first(where: { $0.state == .queued }) {
                queuedID = queued.id
                break
            }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertNotNil(queuedID)
        if let queuedID {
            model.cancelTask(queuedID)
        }
        await run.value

        let downloadRequests = await probe.downloadRequests
        XCTAssertEqual(downloadRequests, 3)
        XCTAssertEqual(model.tasks.filter { $0.state == .cancelled }.count, 1)
        XCTAssertEqual(model.tasks.filter { $0.state == .completed }.count, 3)
        XCTAssertTrue(model.status.contains("1 取消"))
    }

    func testTimeoutIsClassifiedForTaskUI() async {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(
            userDefaults: defaults,
            bridgeStreamingSend: { _, _ in
                throw BridgeClient.BridgeError.timedOut
            },
            bridgeSend: { request in
                BridgeResponse(
                    id: request.id,
                    ok: true,
                    platform: PlatformDetector.detect(request.url ?? ""),
                    message: "ok",
                    details: [:]
                )
            }
        )
        model.input = "https://xhslink.com/timeout"
        await model.runDownload()

        XCTAssertEqual(model.tasks.first?.state, .failed)
        XCTAssertEqual(model.tasks.first?.failureKind, .timeout)
        XCTAssertTrue(model.tasks.first?.detail.contains("任务超时") == true)
    }
}
