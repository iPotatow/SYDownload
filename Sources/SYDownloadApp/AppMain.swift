#if canImport(SwiftUI)
import SwiftUI
import AppKit

@main
struct SYDownloadApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("SYDownload", id: "main") {
            ContentView()
                .environmentObject(model)
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 680)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView(model: model)
                .frame(width: 720, height: 560)
        }
    }
}
#else
import Foundation
import SYDownloadCore

@main
enum SYDownloadLinuxProbe {
    static func main() {
        let probe = PlatformDetector.detect("https://v.douyin.com/demo").rawValue
        print("SYDownload macOS UI requires SwiftUI/AppKit. Core probe OK: \(probe)")
    }
}
#endif
