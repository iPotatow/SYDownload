#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XDownloaderCore

@MainActor
final class AppModel: ObservableObject {
    @Published var input = ""
    @Published var outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "~/Downloads"
    @Published var status = "等待链接"
    @Published var detectedPlatform: DownloadPlatform = .unknown
    @Published var isWorking = false
    @Published var lastDetails: [String: String] = [:]

    private let bridge = BridgeClient()

    func detectLocally() {
        detectedPlatform = PlatformDetector.detect(input)
        status = detectedPlatform == .unknown ? "无法识别链接" : "已识别：\(detectedPlatform.displayName)"
    }

    func validateEngine() async {
        detectLocally()
        guard detectedPlatform != .unknown else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            let response = try await bridge.send(.init(command: "validate", url: input))
            status = response.message
            lastDetails = response.details ?? [:]
        } catch {
            status = error.localizedDescription
        }
    }

    func runDownload() async {
        detectLocally()
        guard detectedPlatform != .unknown else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            let response = try await bridge.send(.init(
                command: "download",
                url: input,
                outputDirectory: outputDirectory
            ))
            status = response.message
            lastDetails = response.details ?? [:]
        } catch {
            status = error.localizedDescription
        }
    }
}

#endif
