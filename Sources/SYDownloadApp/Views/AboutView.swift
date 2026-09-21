#if canImport(SwiftUI)
import AppKit
import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.3.0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.l) {
            header

            Text("自动识别分享链接，并调用内置下载引擎。轻量、直接，内容始终写入你选择的文件夹。")
                .coreTypography(CoreTypography.body)
                .foregroundStyle(CoreColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            capabilityRow

            VStack(alignment: .leading, spacing: CoreSpacing.m) {
                Button("打开 GitHub 仓库", remixSystemImage: "arrow.up.right", action: openRepository)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .font(CoreTypography.controlFont)

                HStack(spacing: CoreSpacing.l) {
                    linkButton("问题反馈", symbol: "bubble.left.and.exclamationmark.bubble.right", url: "https://github.com/iPotatow/SYdownload/issues")
                    linkButton("使用文档", symbol: "doc.text", url: "https://github.com/iPotatow/SYdownload#readme")
                }
            }

            Spacer(minLength: 0)

            Divider()
                .overlay(CoreColor.divider)

            HStack {
                Text("基于 XHS-Downloader 和 TikTokDownloader 构建")
                    .coreTypography(CoreTypography.caption)
                Spacer()
                Text("GPL-3.0")
                    .coreTypography(CoreTypography.caption)
            }
            .foregroundStyle(CoreColor.textTertiary)
        }
        .padding(CoreSpacing.xl)
        .frame(width: 500)
        .frame(minHeight: 380)
        .onExitCommand { dismiss() }
        .background(CoreColor.contentBackground)
        .tint(CoreColor.accent)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: CoreSpacing.l) {
            AppMark(size: 56)
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("SYDownload")
                    .coreTypography(CoreTypography.sectionTitle)
                    .foregroundStyle(CoreColor.textPrimary)
                Text("小红书与抖音下载工具 · v\(version)")
                    .coreTypography(CoreTypography.body)
                    .foregroundStyle(CoreColor.textSecondary)
            }
            Spacer(minLength: CoreSpacing.l)
            Button("关闭", remixSystemImage: "xmark", action: dismiss.callAsFunction)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(CoreColor.textSecondary)
                .help("关闭")
        }
    }

    private var capabilityRow: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.s) {
            capability("本地优先", "链接和配置通过本机 Bridge 处理。", systemImage: "lock.shield", tint: CoreColor.accent)
            capability("自包含", "Release 内置 Python 运行时与下载引擎。", systemImage: "shippingbox", tint: CoreColor.accent)
        }
    }

    private func capability(
        _ title: String,
        _ message: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: CoreSpacing.m) {
            IconBadge(systemImage: systemImage, tint: tint, size: 36)
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text(title)
                    .coreTypography(CoreTypography.control)
                    .foregroundStyle(CoreColor.textPrimary)
                Text(message)
                    .coreTypography(CoreTypography.body)
                    .foregroundStyle(CoreColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(CoreSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            CoreColor.controlBackground,
            in: RoundedRectangle(cornerRadius: CoreRadius.row, style: .continuous)
        )
    }

    private func linkButton(_ title: String, symbol: String, url: String) -> some View {
        Button(title, remixSystemImage: symbol) {
            open(url)
        }
        .buttonStyle(.plain)
        .font(CoreTypography.controlFont)
        .foregroundStyle(CoreColor.textPrimary)
    }

    private func openRepository() {
        open("https://github.com/iPotatow/SYdownload")
    }

    private func open(_ raw: String) {
        guard let url = URL(string: raw) else { return }
        NSWorkspace.shared.open(url)
    }
}
#endif
