#if canImport(SwiftUI)
import SwiftUI
import AppKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2"
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("关闭")
            }

            AppMark(size: 72)

            VStack(spacing: 6) {
                Text("SYDownload")
                    .font(.system(size: 24, weight: .bold))
                Text("v\(version)")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("小红书与抖音下载工具")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Text("自动识别分享链接，并调用内置下载引擎。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            Button("打开 GitHub 仓库") {
                open("https://github.com/iPotatow/SYdownload")
            }
            .buttonStyle(.borderedProminent)

            HStack(spacing: 22) {
                linkButton("源码", symbol: "chevron.left.forwardslash.chevron.right", url: "https://github.com/iPotatow/SYdownload")
                linkButton("问题反馈", symbol: "bubble.left.and.exclamationmark.bubble.right", url: "https://github.com/iPotatow/SYdownload/issues")
                linkButton("使用文档", symbol: "doc.text", url: "https://github.com/iPotatow/SYdownload#readme")
            }
            .font(.system(size: 12))

            Divider()

            VStack(spacing: 4) {
                Text("基于 XHS-Downloader 和 TikTokDownloader 构建")
                Text("GPL-3.0")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(26)
        .frame(width: 480, height: 430)
    }

    private func linkButton(_ title: String, symbol: String, url: String) -> some View {
        Button { open(url) } label: {
            Label(title, systemImage: symbol)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private func open(_ raw: String) {
        guard let url = URL(string: raw) else { return }
        NSWorkspace.shared.open(url)
    }
}
#endif
