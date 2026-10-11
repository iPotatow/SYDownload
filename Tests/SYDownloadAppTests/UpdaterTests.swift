#if canImport(AppKit)
import AppKit
import Foundation
import XCTest
@testable import SYDownloadApp

@MainActor
final class UpdaterTests: XCTestCase {
    func testRequiresHTTPSFeedAndRealEd25519Key() {
        let key = Data(repeating: 1, count: 32).base64EncodedString()
        XCTAssertNil(SYDownloadUpdater.configurationError(in: [
            "SUFeedURL": "https://example.com/appcast.xml", "SUPublicEDKey": key,
        ]))
        XCTAssertNotNil(SYDownloadUpdater.configurationError(in: [
            "SUFeedURL": "http://example.com/appcast.xml", "SUPublicEDKey": key,
        ]))
        XCTAssertNotNil(SYDownloadUpdater.configurationError(in: [
            "SUFeedURL": "https://example.com/appcast.xml", "SUPublicEDKey": "placeholder",
        ]))
    }

    func testQuitWithoutWindowOrModelTerminatesImmediately() {
        XCTAssertEqual(SYDownloadAppDelegate().applicationShouldTerminate(NSApplication.shared), .terminateNow)
    }

    func testQuitWithCleanSettingsTerminatesImmediately() {
        let suite = "SYDownload.QuitTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(userDefaults: defaults)
        let delegate = SYDownloadAppDelegate()
        delegate.model = model
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateNow)
        XCTAssertFalse(model.pendingTermination)
    }
    func testCancelQuitPreservesUnsavedSettingsAndResetsPendingState() async {
        let suite = "SYDownload.CancelQuitTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(userDefaults: defaults)
        model.xhsSettingsDirty = true
        let shouldQuit = await SYDownloadAppDelegate().resolveTerminationDecision(.alertThirdButtonReturn, model: model)
        XCTAssertFalse(shouldQuit)
        XCTAssertTrue(model.hasUnsavedSettings)
        XCTAssertFalse(model.pendingTermination)
    }

    func testDiscardAllowsQuitWithoutReloadingEngineSettings() async {
        let suite = "SYDownload.DiscardQuitTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(userDefaults: defaults, bridgeSend: { _ in
            XCTFail("Discard during quit must not start a bridge request")
            throw BridgeClient.BridgeError.bridgeNotFound
        })
        model.xhsSettingsDirty = true
        model.douyinSettingsDirty = true
        let shouldQuit = await SYDownloadAppDelegate().resolveTerminationDecision(.alertSecondButtonReturn, model: model)
        XCTAssertTrue(shouldQuit)
        XCTAssertFalse(model.hasUnsavedSettings)
        XCTAssertFalse(model.pendingTermination)
    }

}
#endif
