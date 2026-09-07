#if canImport(SwiftUI)
import AppKit
import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceXL) {
            header

            Text("自动识别分享链接，并调用内置下载引擎。轻量、直接，内容始终写入你选择的文件夹。")
                .font(DesignSystem.bodyFont)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            capabilityRow

            VStack(alignment: .leading, spacing: DesignSystem.spaceM) {
                Button("打开 GitHub 仓库", systemImage: "arrow.up.right", action: openRepository)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                HStack(spacing: DesignSystem.spaceL) {
                    linkButton("源码", symbol: "chevron.left.forwardslash.chevron.right", url: "https://github.com/iPotatow/SYdownload")
                    linkButton("问题反馈", symbol: "bubble.left.and.exclamationmark.bubble.right", url: "https://github.com/iPotatow/SYdownload/issues")
                    linkButton("使用文档", symbol: "doc.text", url: "https://github.com/iPotatow/SYdownload#readme")
                }
            }

            Spacer(minLength: 0)

            Divider()

            HStack {
                Text("基于 XHS-Downloader 和 TikTokDownloader 构建")
                Spacer()
                Text("GPL-3.0")
            }
            .font(DesignSystem.metadataFont)
            .foregroundStyle(.tertiary)
        }
        .padding(DesignSystem.spaceXL)
        .frame(width: 500, height: 390)
        .background(DesignSystem.mainSurfaceBackground)
        .tint(DesignSystem.accent)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DesignSystem.spaceL) {
            AppMark(size: 56)
            VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                Text("SYDownload")
                    .font(DesignSystem.pageTitleFont)
                Text("小红书与抖音下载工具 · v\(version)")
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: DesignSystem.spaceL)
            Button("关闭", systemImage: "xmark", action: dismiss.callAsFunction)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("关闭")
        }
    }

    private var capabilityRow: some View {
        HStack(spacing: DesignSystem.spaceM) {
            capability("本地优先", "链接和配置通过本机 Bridge 处理。", systemImage: "lock.shield", tint: DesignSystem.success)
            capability("自包含", "Release 内置 Python 运行时与下载引擎。", systemImage: "shippingbox", tint: DesignSystem.accent)
        }
    }

    private func capability(
        _ title: String,
        _ message: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: DesignSystem.spaceM) {
            IconBadge(systemImage: systemImage, tint: tint, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.uiFont.weight(.semibold))
                Text(message)
                    .font(DesignSystem.supportingFont)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DesignSystem.spaceM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            DesignSystem.rowBackground,
            in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
        )
    }

    private func linkButton(_ title: String, symbol: String, url: String) -> some View {
        Button(title, systemImage: symbol) {
            open(url)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
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
