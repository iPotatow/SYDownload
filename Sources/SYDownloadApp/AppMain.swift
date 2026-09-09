#if canImport(SwiftUI)
import SwiftUI
import AppKit

@main
struct SYDownloadApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var updater = SYDownloadUpdater(owner: "iPotatow", repo: "SYDownload")

    var body: some Scene {
        WindowGroup("SYDownload", id: "main") {
            ContentView()
                .environmentObject(model)
                .environmentObject(updater)
                .sheet(isPresented: $updater.sheet) {
                    SYDownloadUpdateSheet(updater: updater)
                }
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: DesignSystem.windowWidth, height: DesignSystem.windowHeight)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建下载") {
                    NotificationCenter.default.post(name: .syDownloadNewDownload, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }

            CommandGroup(after: .pasteboard) {
                Button("搜索任务或历史记录") {
                    NotificationCenter.default.post(name: .syDownloadFocusSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command])
                .disabled(model.selection != .tasks && model.selection != .history)
            }

            CommandGroup(replacing: .appInfo) {
                Button("关于 SYDownload") {
                    NotificationCenter.default.post(name: .syDownloadShowAbout, object: nil)
                }
            }

            CommandGroup(after: .appInfo) {
                Button("检查更新…") {
                    updater.checkForUpdates(sheet: true, force: true)
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
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
    static let syDownloadFocusDownloadInput = Notification.Name("SYDownload.focusDownloadInput")
    static let syDownloadFocusSearch = Notification.Name("SYDownload.focusSearch")
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
