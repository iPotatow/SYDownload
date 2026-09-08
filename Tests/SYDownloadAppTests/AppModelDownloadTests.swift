import Foundation
import XCTest
@testable import SYDownloadApp
import SYDownloadCore

private actor TestGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}

private actor RequestRecorder {
    var requests: [BridgeRequest] = []
    var responseError: Error?
    var validateGate: TestGate?
    var downloadGate: TestGate?
    var rejectedValidationURLs: Set<String> = []

    func handle(_ request: BridgeRequest) async throws -> BridgeResponse {
        requests.append(request)
        if request.command == "validate", let validateGate {
            await validateGate.wait()
        }
        if request.command == "download", let downloadGate {
            await downloadGate.wait()
        }
        if let responseError { throw responseError }

        let rejected = request.command == "validate"
            && rejectedValidationURLs.contains(request.url ?? "")
        let payload: [String: Any] = [
            "ok": !rejected,
            "platform": PlatformDetector.detect(request.url ?? "").rawValue,
            "message": rejected ? "rejected" : "ok",
            "details": [:]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        return try! JSONDecoder().decode(BridgeResponse.self, from: data)
    }

    func requests(for command: String) -> [BridgeRequest] {
        requests.filter { $0.command == command }
    }
}

@MainActor
final class AppModelDownloadTests: XCTestCase {
    private func makeModel(
        recorder: RequestRecorder,
        name: String = #function
    ) -> (AppModel, UserDefaults, String) {
        let suiteName = "SYDownload.AppModelDownloadTests.\(name).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let model = AppModel(
            userDefaults: defaults,
            bridgeStreamingSend: { request, _ in
                try await recorder.handle(request)
            }
        ) { request in
            try await recorder.handle(request)
        }
        return (model, defaults, suiteName)
    }

    private func waitForRequestCount(
        _ recorder: RequestRecorder,
        command: String,
        count: Int
    ) async {
        for _ in 0..<100 {
            if await recorder.requests(for: command).count >= count { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Timed out waiting for \(command) request")
    }

    func testConcurrentRunDownloadOnlyValidatesAndDownloadsOnce() async {
        let recorder = RequestRecorder()
        let downloadGate = TestGate()
        await recorder.setDownloadGate(downloadGate)
        let (model, defaults, suiteName) = makeModel(recorder: recorder)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        model.input = "https://www.xiaohongshu.com/explore/repeated"
        model.detectLocally()
        let first = Task { await model.runDownload() }
        await waitForRequestCount(recorder, command: "download", count: 1)

        // The first download is still in flight, so a repeated click must be ignored.
        let second = Task { await model.runDownload() }
        await second.value
        await downloadGate.open()
        await first.value

        let requests = await recorder.requests
        XCTAssertEqual(requests.filter { $0.command == "validate" }.count, 1)
        XCTAssertEqual(requests.filter { $0.command == "download" }.count, 1)
    }

    func testChangingInputOnSamePlatformInvalidatesValidation() async {
        let recorder = RequestRecorder()
        let (model, defaults, suiteName) = makeModel(recorder: recorder)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        model.input = "https://www.xiaohongshu.com/explore/old"
        await model.validateEngine()
        XCTAssertEqual(model.validatedInput, "https://www.xiaohongshu.com/explore/old")

        model.input = "https://www.xiaohongshu.com/explore/new"
        model.detectLocally()
        XCTAssertEqual(model.validatedInput, "")
    }

    func testInputChangedWhileValidationAwaitsDoesNotDownloadNewURL() async {
        let recorder = RequestRecorder()
        let gate = TestGate()
        await recorder.setValidateGate(gate)
        let (model, defaults, suiteName) = makeModel(recorder: recorder)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        model.input = "https://www.xiaohongshu.com/explore/old"
        model.detectLocally()
        let run = Task { await model.runDownload() }
        await waitForRequestCount(recorder, command: "validate", count: 1)

        model.input = "https://www.xiaohongshu.com/explore/new"
        await gate.open()
        await run.value

        let downloads = await recorder.requests(for: "download").count
        XCTAssertEqual(downloads, 0)
        XCTAssertTrue(model.tasks.isEmpty)
    }

    func testOutputDirectoryIsSnapshottedBeforeValidationAndUsedInHistory() async {
        let recorder = RequestRecorder()
        let gate = TestGate()
        await recorder.setValidateGate(gate)
        let (model, defaults, suiteName) = makeModel(recorder: recorder)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let originalDirectory = "/tmp/SYDownload-original"
        let changedDirectory = "/tmp/SYDownload-changed"
        model.outputDirectory = originalDirectory
        model.input = "https://www.xiaohongshu.com/explore/snapshot"
        model.detectLocally()
        let run = Task { await model.runDownload() }
        await waitForRequestCount(recorder, command: "validate", count: 1)
        model.outputDirectory = changedDirectory
        await gate.open()
        await run.value

        let download = await recorder.requests(for: "download").first
        XCTAssertEqual(download?.outputDirectory, originalDirectory)
        XCTAssertEqual(model.history.first?.outputDirectory, originalDirectory)
    }

    func testStaleValidationErrorDoesNotOverwriteCurrentStatus() async {
        let recorder = RequestRecorder()
        let gate = TestGate()
        await recorder.setValidateGate(gate)
        let (model, defaults, suiteName) = makeModel(recorder: recorder)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        struct StaleError: LocalizedError { var errorDescription: String? { "stale error" } }
        await recorder.setResponseError(StaleError())
        model.input = "https://www.xiaohongshu.com/explore/stale"
        model.detectLocally()
        let validation = Task { await model.validateEngine() }
        await waitForRequestCount(recorder, command: "validate", count: 1)

        model.input = "https://www.xiaohongshu.com/explore/current"
        model.status = "当前输入仍然有效"
        model.statusIsError = false
        await gate.open()
        await validation.value

        XCTAssertEqual(model.status, "当前输入仍然有效")
        XCTAssertFalse(model.statusIsError)
        XCTAssertEqual(model.validatedInput, "")
    }

    func testMixedBatchCreatesOneTaskPerUniqueLink() async {
        let recorder = RequestRecorder()
        let (model, defaults, suiteName) = makeModel(recorder: recorder)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let xhs = "https://xhslink.com/abc"
        let douyin = "https://v.douyin.com/xyz/"
        let unsupported = "https://example.com/item"
        let tiktok = "https://www.tiktok.com/@user/video/1"
        model.input = """
        小红书 \(xhs)。
        抖音 \(douyin)
        重复 \(xhs)
        其他 \(unsupported);
        TikTok \(tiktok)
        """

        await model.runDownload()

        let validations = await recorder.requests(for: "validate")
        let downloads = await recorder.requests(for: "download")
        XCTAssertEqual(validations.map(\.url), [xhs, douyin])
        XCTAssertEqual(Set(downloads.compactMap(\.url)), Set([xhs, douyin]))
        XCTAssertEqual(downloads.count, 2)
        XCTAssertEqual(model.tasks.map(\.sourceURL), [xhs, douyin, unsupported, tiktok])
        XCTAssertEqual(model.tasks.count, 4)
        XCTAssertEqual(model.tasks.first(where: { $0.sourceURL == unsupported })?.state, .failed)
        XCTAssertEqual(model.tasks.first(where: { $0.sourceURL == tiktok })?.state, .failed)
        XCTAssertEqual(model.history.map(\.sourceURL), [xhs, douyin])
        XCTAssertEqual(model.status, "批量下载完成：2 成功，2 失败")
    }

    func testValidationFailureDoesNotBlockOtherLinks() async {
        let recorder = RequestRecorder()
        let (model, defaults, suiteName) = makeModel(recorder: recorder)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let rejected = "https://xhslink.com/rejected"
        let accepted = "https://v.douyin.com/accepted/"
        await recorder.setRejectedValidationURLs([rejected])
        model.input = "\(rejected)\n\(accepted)"

        await model.runDownload()

        let downloads = await recorder.requests(for: "download")
        XCTAssertEqual(downloads.map(\.url), [accepted])
        XCTAssertEqual(model.tasks.first(where: { $0.sourceURL == rejected })?.state, .failed)
        XCTAssertEqual(model.tasks.first(where: { $0.sourceURL == accepted })?.state, .completed)
        XCTAssertEqual(model.history.map(\.sourceURL), [accepted])
        XCTAssertEqual(model.status, "批量下载完成：1 成功，1 失败")
    }
}

private extension RequestRecorder {
    func setValidateGate(_ gate: TestGate) {
        validateGate = gate
    }

    func setResponseError(_ error: Error?) {
        responseError = error
    }

    func setDownloadGate(_ gate: TestGate) {
        downloadGate = gate
    }

    func setRejectedValidationURLs(_ urls: Set<String>) {
        rejectedValidationURLs = urls
    }
}
