#if canImport(SwiftUI)
import SwiftUI
import AppKit

@main
struct XDownloaderApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("XDownloader", id: "main") {
            ContentView()
                .environmentObject(model)
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView(model: model)
                .frame(width: 720, height: 560)
        }
    }
}
#else
import Foundation
import XDownloaderCore

@main
enum XDownloaderLinuxProbe {
    static func main() {
        let probe = PlatformDetector.detect("https://v.douyin.com/demo").rawValue
        print("XDownloader macOS UI requires SwiftUI/AppKit. Core probe OK: \(probe)")
    }
}
#endif
