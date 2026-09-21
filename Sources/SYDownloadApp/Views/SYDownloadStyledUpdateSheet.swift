#if canImport(SwiftUI)
import AppKit
import SwiftUI

struct SYDownloadStyledUpdateSheet: View {
    @ObservedObject var updater: SYDownloadUpdater
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.l) {
            HStack(alignment: .top, spacing: CoreSpacing.l) {
                VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                    Text("SYDownload 更新")
                        .coreTypography(CoreTypography.sectionTitle)
                        .foregroundStyle(CoreColor.textPrimary)
                    Text("当前版本：\(updater.displayVersion)")
                        .coreTypography(CoreTypography.caption)
                        .foregroundStyle(CoreColor.textSecondary)
                }
                Spacer()
                if updater.isChecking {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(spacing: CoreSpacing.m) {
                Text("更新来源")
                    .coreTypography(CoreTypography.body)
                    .foregroundStyle(CoreColor.textPrimary)
                Spacer()
                Picker("更新来源", selection: $updater.updateSource) {
                    ForEach(SYDownloadUpdateSource.allCases) { source in
                        Text(source.displayName).tag(source)
                    }
                }
                .labelsHidden()
                .font(CoreTypography.controlFont)
                .frame(width: 168, height: CoreMetrics.controlHeightDefault)

                Button("重新检查") {
                    updater.checkForUpdates(sheet: true, force: true)
                }
                .font(CoreTypography.controlFont)
                .frame(height: CoreMetrics.controlHeightDefault)
                .disabled(updater.isChecking || updater.isUpdating)
            }

            CorePanel {
                updateContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity)

            if updater.isUpdating {
                VStack(alignment: .leading, spacing: CoreSpacing.s) {
                    ProgressView(value: updater.progressBar.1)
                    Text(updater.progressBar.0)
                        .coreTypography(CoreTypography.caption)
                        .foregroundStyle(CoreColor.textSecondary)
                }
            }

            HStack(spacing: CoreSpacing.m) {
                Button("关闭") { dismiss() }
                    .font(CoreTypography.controlFont)
                Spacer()
                if let url = URL(string: "https://github.com/\(updater.owner)/\(updater.repo)/releases") {
                    Button("Release 页面") { NSWorkspace.shared.open(url) }
                        .font(CoreTypography.controlFont)
                }
                Button("更新并重启") {
                    updater.downloadUpdate()
                }
                .font(CoreTypography.controlFont)
                .buttonStyle(.borderedProminent)
                .tint(CoreColor.accent)
                .disabled(!updater.hasNewerRelease || updater.isChecking || updater.isUpdating)
            }
        }
        .padding(CoreSpacing.xl)
        .frame(width: 600, height: 460)
        .background(CoreColor.contentBackground)
        .tint(CoreColor.accent)
    }

    @ViewBuilder
    private var updateContent: some View {
        if let error = updater.updateError {
            VStack(alignment: .leading, spacing: CoreSpacing.s) {
                Label {
                    Text("更新检查失败")
                        .coreTypography(CoreTypography.control)
                } icon: {
                    RemixIcon(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(CoreColor.warning)
                }
                Text(error)
                    .coreTypography(CoreTypography.body)
                    .foregroundStyle(CoreColor.textSecondary)
                    .textSelection(.enabled)
            }
        } else if let release = updater.latestRelease {
            ScrollView {
                VStack(alignment: .leading, spacing: CoreSpacing.m) {
                    HStack(alignment: .firstTextBaseline, spacing: CoreSpacing.m) {
                        Text(release.name.isEmpty ? release.tagName : release.name)
                            .coreTypography(CoreTypography.sectionTitle)
                            .foregroundStyle(CoreColor.textPrimary)
                        Spacer()
                        Text(release.tagName)
                            .coreTypography(CoreTypography.caption)
                            .foregroundStyle(CoreColor.textSecondary)
                            .monospaced()
                    }

                    if updater.hasNewerRelease {
                        Label("发现新版本", remixSystemImage: "arrow.down.circle.fill")
                            .font(CoreTypography.controlFont)
                            .foregroundStyle(CoreColor.accent)
                    } else {
                        Label("已是最新版本", remixSystemImage: "checkmark.circle.fill")
                            .font(CoreTypography.controlFont)
                            .foregroundStyle(CoreColor.success)
                    }

                    if release.body.isEmpty {
                        Text("该版本没有发布说明。")
                            .coreTypography(CoreTypography.body)
                            .foregroundStyle(CoreColor.textSecondary)
                    } else {
                        Text(release.body)
                            .coreTypography(CoreTypography.body)
                            .foregroundStyle(CoreColor.textSecondary)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if updater.isChecking {
            HStack(spacing: CoreSpacing.s) {
                ProgressView().controlSize(.small)
                Text("正在检查更新…")
                    .coreTypography(CoreTypography.body)
                    .foregroundStyle(CoreColor.textSecondary)
            }
        } else {
            Text("暂无 Release 信息。")
                .coreTypography(CoreTypography.body)
                .foregroundStyle(CoreColor.textSecondary)
        }
    }
}
#endif
