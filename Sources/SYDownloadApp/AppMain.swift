#if canImport(SwiftUI)
import SwiftUI
import AppKit

@main
struct SYDownloadApp: App {
    @NSApplicationDelegateAdaptor(SYDownloadAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var updater = SYDownloadUpdater(owner: "iPotatow", repo: "SYDownload")

    var body: some Scene {
        WindowGroup("SYDownload", id: "main") {
            ContentView()
                .tint(CoreColor.accent)
                .environmentObject(model)
                .environmentObject(updater)
                .sheet(isPresented: $updater.sheet) {
                    SYDownloadStyledUpdateSheet(updater: updater)
                }
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: SYDownloadLayout.windowWidth, height: SYDownloadLayout.windowHeight)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建下载") {
                    model.requestSelection(.download)
                    if model.selection == .download {
                        NotificationCenter.default.post(name: .syDownloadFocusDownloadInput, object: nil)
                    }
                }
                .keyboardShortcut("n", modifiers: [.command])
            }

            CommandMenu("导航") {
                navigationCommand("下载", section: .download, key: "1")
                navigationCommand("任务", section: .tasks, key: "2")
                navigationCommand("历史记录", section: .history, key: "3")
                navigationCommand("照片整理", section: .photos, key: "4")
                navigationCommand("设置", section: .settings, key: "5")
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
                    model.openSettings(.general)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }

    private func navigationCommand(_ title: String, section: AppSection, key: KeyEquivalent) -> some View {
        Button(title) {
            if section == .settings {
                model.openSettings(.general)
            } else {
                model.requestSelection(section)
            }
        }
        .keyboardShortcut(key, modifiers: [.command])
    }
}

final class SYDownloadAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        NotificationCenter.default.post(name: .syDownloadRequestTermination, object: nil)
        return .terminateLater
    }
}

extension Notification.Name {
    static let syDownloadNewDownload = Notification.Name("SYDownload.newDownload")
    static let syDownloadShowAbout = Notification.Name("SYDownload.showAbout")
    static let syDownloadShowSettings = Notification.Name("SYDownload.showSettings")
    static let syDownloadFocusDownloadInput = Notification.Name("SYDownload.focusDownloadInput")
    static let syDownloadFocusSearch = Notification.Name("SYDownload.focusSearch")
    static let syDownloadRequestTermination = Notification.Name("SYDownload.requestTermination")
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