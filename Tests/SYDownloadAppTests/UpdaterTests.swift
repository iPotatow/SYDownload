#if canImport(AppKit)
import Foundation
import XCTest
@testable import SYDownloadApp

final class UpdaterTests: XCTestCase {
    func testVersionComparisonHandlesPrefixAndMissingPatch() throws {
        let old = try XCTUnwrap(SYDownloadVersion("v0.2"))
        let current = try XCTUnwrap(SYDownloadVersion("0.3.0"))
        let newer = try XCTUnwrap(SYDownloadVersion("v0.3.1-beta"))

        XCTAssertLessThan(old, current)
        XCTAssertLessThan(current, newer)
        XCTAssertEqual(SYDownloadVersion("v0.3.0"), current)
    }

    func testUpdateEndpointUsesGatePassMirrorRules() throws {
        let original = try XCTUnwrap(URL(string: "https://api.github.com/repos/iPotatow/SYDownload/releases"))

        XCTAssertEqual(SYDownloadUpdateEndpoint.resolve(originalURL: original, source: .github), original)
        XCTAssertEqual(
            SYDownloadUpdateEndpoint.resolve(originalURL: original, source: .ghProxy)?.absoluteString,
            "https://gh-proxy.com/https://api.github.com/repos/iPotatow/SYDownload/releases"
        )
        XCTAssertEqual(
            SYDownloadUpdateEndpoint.resolve(originalURL: original, source: .ghproxyNet)?.absoluteString,
            "https://ghproxy.net/https://api.github.com/repos/iPotatow/SYDownload/releases"
        )
    }

    func testInstallerScriptVerifiesBundleBeforeSwapAndKeepsRollback() throws {
        let staged = URL(fileURLWithPath: "/tmp/Staged/SYDownload.app")
        let destination = URL(fileURLWithPath: "/Applications/SYDownload.app")
        let root = URL(fileURLWithPath: "/tmp/SYDownload/Updates/test")
        let script = SYDownloadUpdateInstaller.installScript(
            stagedApp: staged,
            destination: destination,
            updateRoot: root,
            backupName: ".SYDownload-backup-test",
            expectedBundleIdentifier: "com.sydownload.app",
            expectedVersion: "0.3.0"
        )

        XCTAssertTrue(script.contains("verify_bundle \"$candidate\""))
        XCTAssertTrue(script.contains("/bin/mv \"$old\" \"$backup\""))
        XCTAssertTrue(script.contains("restore_backup"))
        XCTAssertTrue(script.contains("write_status \"installed\""))
    }
}
#endif
