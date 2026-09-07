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
        .defaultSize(width: 1060, height: 680)

        Settings {
            Form {
                Text("可行性验证版：引擎通过 Python Bridge 接入。")
                Text("正式版再加入 Cookie 管理、下载队列、历史记录、签名与公证。")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(width: 480)
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
