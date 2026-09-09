#if canImport(SwiftUI)
import AppKit
import SwiftUI

struct SYDownloadStyledUpdateSheet: View {
    @ObservedObject var updater: SYDownloadUpdater
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
            HStack(alignment: .top, spacing: DesignSystem.spaceL) {
                VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                    Text("SYDownload 更新")
                        .syTypography(DesignSystem.typographySectionTitle)
                        .foregroundStyle(DesignSystem.textPrimary)
                    Text("当前版本：\(updater.displayVersion)")
                        .syTypography(DesignSystem.typographyCaption)
                        .foregroundStyle(DesignSystem.textSecondary)
                }
                Spacer()
                if updater.isChecking {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(spacing: DesignSystem.spaceM) {
                Text("更新来源")
                    .syTypography(DesignSystem.typographyBody)
                    .foregroundStyle(DesignSystem.textPrimary)
                Spacer()
                Picker("更新来源", selection: $updater.updateSource) {
                    ForEach(SYDownloadUpdateSource.allCases) { source in
                        Text(source.displayName).tag(source)
                    }
                }
                .labelsHidden()
                .font(DesignSystem.uiFont)
                .frame(width: 168, height: DesignSystem.controlHeightDefault)

                Button("重新检查") {
                    updater.checkForUpdates(sheet: true, force: true)
                }
                .font(DesignSystem.uiFont)
                .frame(height: DesignSystem.controlHeightDefault)
                .disabled(updater.isChecking || updater.isUpdating)
            }

            SurfaceCard {
                updateContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity)

            if updater.isUpdating {
                VStack(alignment: .leading, spacing: DesignSystem.spaceS) {
                    ProgressView(value: updater.progressBar.1)
                    Text(updater.progressBar.0)
                        .syTypography(DesignSystem.typographyCaption)
                        .foregroundStyle(DesignSystem.textSecondary)
                }
            }

            HStack(spacing: DesignSystem.spaceM) {
                Button("关闭") { dismiss() }
                    .font(DesignSystem.uiFont)
                Spacer()
                if let url = URL(string: "https://github.com/\(updater.owner)/\(updater.repo)/releases") {
                    Button("Release 页面") { NSWorkspace.shared.open(url) }
                        .font(DesignSystem.uiFont)
                }
                Button("更新并重启") {
                    updater.downloadUpdate()
                }
                .font(DesignSystem.uiFont)
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.accent)
                .disabled(!updater.hasNewerRelease || updater.isChecking || updater.isUpdating)
            }
        }
        .padding(DesignSystem.spaceXL)
        .frame(width: 600, height: 460)
        .background(DesignSystem.mainSurfaceBackground)
        .tint(DesignSystem.accent)
    }

    @ViewBuilder
    private var updateContent: some View {
        if let error = updater.updateError {
            VStack(alignment: .leading, spacing: DesignSystem.spaceS) {
                Label {
                    Text("更新检查失败")
                        .syTypography(DesignSystem.typographyControl)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DesignSystem.semanticWarning)
                }
                Text(error)
                    .syTypography(DesignSystem.typographyBody)
                    .foregroundStyle(DesignSystem.textSecondary)
                    .textSelection(.enabled)
            }
        } else if let release = updater.latestRelease {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.spaceM) {
                    HStack(alignment: .firstTextBaseline, spacing: DesignSystem.spaceM) {
                        Text(release.name.isEmpty ? release.tagName : release.name)
                            .syTypography(DesignSystem.typographySectionTitle)
                            .foregroundStyle(DesignSystem.textPrimary)
                        Spacer()
                        Text(release.tagName)
                            .syTypography(DesignSystem.typographyCaption)
                            .foregroundStyle(DesignSystem.textSecondary)
                            .monospaced()
                    }

                    if updater.hasNewerRelease {
                        Label("发现新版本", systemImage: "arrow.down.circle.fill")
                            .font(DesignSystem.uiFont)
                            .foregroundStyle(DesignSystem.accent)
                    } else {
                        Label("已是最新版本", systemImage: "checkmark.circle.fill")
                            .font(DesignSystem.uiFont)
                            .foregroundStyle(DesignSystem.semanticSuccess)
                    }

                    if release.body.isEmpty {
                        Text("该版本没有发布说明。")
                            .syTypography(DesignSystem.typographyBody)
                            .foregroundStyle(DesignSystem.textSecondary)
                    } else {
                        Text(release.body)
                            .syTypography(DesignSystem.typographyBody)
                            .foregroundStyle(DesignSystem.textSecondary)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if updater.isChecking {
            HStack(spacing: DesignSystem.spaceS) {
                ProgressView().controlSize(.small)
                Text("正在检查更新…")
                    .syTypography(DesignSystem.typographyBody)
                    .foregroundStyle(DesignSystem.textSecondary)
            }
        } else {
            Text("暂无 Release 信息。")
                .syTypography(DesignSystem.typographyBody)
                .foregroundStyle(DesignSystem.textSecondary)
        }
    }
}
#endif
