#if canImport(AppKit) && canImport(SwiftUI)
import Combine
import Foundation
import Sparkle

@MainActor
final class SYDownloadUpdater: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    let configurationError: String?
    private var controller: SPUStandardUpdaterController?

    var displayVersion: String {
        "v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0")"
    }

    static func configurationError(in info: [String: Any]) -> String? {
        guard let feed = info["SUFeedURL"] as? String,
              let url = URL(string: feed), url.scheme == "https", url.host != nil else {
            return "尚未配置 HTTPS 更新源。"
        }
        guard let key = info["SUPublicEDKey"] as? String,
              Data(base64Encoded: key)?.count == 32 else {
            return "尚未配置 Sparkle 更新签名公钥。"
        }
        return nil
    }

    init() {
        configurationError = Self.configurationError(in: Bundle.main.infoDictionary ?? [:])
        guard configurationError == nil else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
        )
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        controller?.checkForUpdates(nil)
    }
}
#endif
