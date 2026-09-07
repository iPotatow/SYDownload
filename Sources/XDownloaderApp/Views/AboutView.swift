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
                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            AppMark(size: 76)

            VStack(spacing: 6) {
                Text("XDownloader").font(.system(size: 24, weight: .bold))
                Text("v\(version)").foregroundStyle(.secondary)
                Text("一站式下载小红书 / 抖音 / TikTok 精彩内容")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Text("好内容，值得被保留").font(.title3.weight(.semibold))

            Button("访问项目主页") { open("https://github.com/iPotatow/SYdownload") }
                .buttonStyle(.borderedProminent)

            HStack(spacing: 22) {
                linkButton("GitHub", symbol: "chevron.left.forwardslash.chevron.right", url: "https://github.com/iPotatow/SYdownload")
                linkButton("问题反馈", symbol: "bubble.left.and.exclamationmark.bubble.right", url: "https://github.com/iPotatow/SYdownload/issues")
                linkButton("使用文档", symbol: "doc.text", url: "https://github.com/iPotatow/SYdownload#readme")
            }
            .font(.system(size: 12))

            Divider()

            VStack(spacing: 4) {
                Text("基于 XHS-Downloader 和 TikTokDownloader 构建")
                Text("遵守 GPL-3.0 开源协议")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 510, height: 470)
    }

    private func linkButton(_ title: String, symbol: String, url: String) -> some View {
        Button { open(url) } label: { Label(title, systemImage: symbol) }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
    }

    private func open(_ raw: String) {
        guard let url = URL(string: raw) else { return }
        NSWorkspace.shared.open(url)
    }
}
#endif
