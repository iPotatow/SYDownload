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
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建下载") {
                    NotificationCenter.default.post(name: .syDownloadNewDownload, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
            CommandGroup(replacing: .appInfo) {
                Button("关于 SYDownload") {
                    NotificationCenter.default.post(name: .syDownloadShowAbout, object: nil)
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("设置…") {
                    NotificationCenter.default.post(name: .syDownloadShowSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let syDownloadNewDownload = Notification.Name("SYDownload.newDownload")
    static let syDownloadShowAbout = Notification.Name("SYDownload.showAbout")
    static let syDownloadShowSettings = Notification.Name("SYDownload.showSettings")
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
