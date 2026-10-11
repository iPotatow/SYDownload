#if canImport(SwiftUI)
import SwiftUI
import AppKit
import SYDownloadCore

struct DownloadView: View {
    @ObservedObject var model: AppModel
    @FocusState private var linkEditorFocused: Bool

    var body: some View {
        CorePageContainer(title: "下载", maxWidth: SYDownloadLayout.contentMaxWidth) {
            ScrollView {
                VStack(alignment: .leading, spacing: CoreSpacing.l) {
                    composer
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, CoreSpacing.l)
            }
        }
        .onChange(of: model.input) { _, _ in model.detectLocally() }
        .onReceive(NotificationCenter.default.publisher(for: .syDownloadFocusDownloadInput)) { _ in
            linkEditorFocused = true
        }
        .tint(CoreColor.accent)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Text("添加下载链接")
                    .coreTypography(CoreTypography.sectionTitle)
                Spacer()
                platformChip(.xiaohongshu)
                platformChip(.douyin)
            }

            TextField("粘贴链接或完整分享文本…", text: $model.input, axis: .vertical)
                .textFieldStyle(.plain)
                .font(CoreTypography.bodyFont)
                .lineLimit(8...12)
                .padding(.horizontal, CoreMetrics.controlHorizontalPadding)
                .padding(.vertical, CoreSpacing.s)
                .frame(height: SYDownloadLayout.downloadComposerHeight, alignment: .topLeading)
                .coreInputSurface(
                    isFocused: linkEditorFocused,
                    isError: inputShowsError
                )
                .focused($linkEditorFocused)
                .accessibilityLabel("下载链接")

            HStack(spacing: CoreSpacing.s) {
                Text("每行一个链接，也可以直接粘贴完整分享文本")
                    .coreTypography(CoreTypography.caption)
                    .foregroundStyle(CoreColor.textTertiary)

                Spacer(minLength: CoreSpacing.m)

                if !model.input.isEmpty {
                    Button("清空", remixSystemImage: "xmark", action: model.clearInput)
                        .coreAction(.tertiary)
                        .foregroundStyle(CoreColor.textSecondary)
                }
            }

            destinationRow

            HStack(spacing: CoreSpacing.m) {
                statusPanel
                Spacer(minLength: 8)

                Button("检查链接", remixSystemImage: "checkmark.circle", action: validate)
                    .coreAction()
                    .disabled(actionsDisabled)

                Button(downloadButtonTitle, remixSystemImage: "arrow.down", action: download)
                    .coreAction(.primary)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(actionsDisabled)
            }
        }
    }

    private var destinationRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "folder").font(.system(size: 20, weight: .light))
                    .foregroundStyle(CoreColor.textSecondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("保存位置").font(.system(size: 11, weight: .medium))
                    Text(model.outputDirectory).font(.system(size: 11))
                        .foregroundStyle(model.outputDirectoryIssue == nil ? CoreColor.textSecondary : CoreColor.danger)
                        .lineLimit(1).truncationMode(.middle).help(model.outputDirectory)
                }
                Spacer(minLength: 8)
                Button("在 Finder 中显示", systemImage: "arrow.up.forward.square") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: NSString(string: model.outputDirectory).expandingTildeInPath, isDirectory: true))
                }
                .coreIconControl().help("在 Finder 中显示")
                .disabled(!model.outputDirectoryExists)
                Button("更改") { model.openSettings(.downloadDirectory) }
                    .coreAction(.tertiary)
                    .disabled(model.activeTaskCount > 0)
            }
            if let issue = model.outputDirectoryIssue {
                Text(issue).font(.system(size: 11)).foregroundStyle(CoreColor.danger)
            } else if model.activeTaskCount > 0 {
                Text("下载期间无法更改保存位置。")
                    .font(.system(size: 11)).foregroundStyle(CoreColor.textSecondary)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(CoreColor.panelBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private func platformChip(_ platform: DownloadPlatform) -> some View {
        let count = platformCount(for: platform)
        return HStack(spacing: 5) {
            PlatformBrandIcon(platform: platform, size: 14, cornerRadius: 3)
            Text(platform.displayName).font(.system(size: 11))
            if count > 0 { Text("\(count)").font(.system(size: 11, weight: .semibold)).monospacedDigit() }
        }
        .foregroundStyle(count > 0 ? CoreColor.accent : CoreColor.textSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(platform.displayName) \(count) 个链接")
    }

    private var statusPanel: some View {
        HStack(spacing: 8) {
            if model.isParsing || model.isWorking {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: CoreMetrics.controlIconSize, height: CoreMetrics.controlIconSize)
            } else {
                RemixIcon(systemName: statusSymbol, size: CoreMetrics.controlIconSize)
                    .foregroundStyle(statusColor)
                    .frame(width: CoreMetrics.controlIconSize, height: CoreMetrics.controlIconSize)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text(visibleStatus)
                    .coreTypography(CoreTypography.control)
                    .foregroundStyle(model.statusIsError ? CoreColor.danger : CoreColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(statusDetail)
                    .coreTypography(CoreTypography.caption)
                    .foregroundStyle(CoreColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: CoreSpacing.m)

            if model.supportedLinkCount > 0 {
                Text("\(model.supportedLinkCount) 项")
                    .coreTypography(CoreTypography.groupLabel)
                    .foregroundStyle(CoreColor.textSecondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var inputShowsError: Bool {
        !model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && model.statusIsError
            && !model.isParsing
            && !model.isWorking
    }

    private var actionsDisabled: Bool {
        !model.hasSupportedLinks
            || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || model.isParsing
            || model.outputDirectoryIssue != nil
    }

    private var platformStatus: String {
        if model.detectedLinks.isEmpty {
            return model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "粘贴链接后即可开始"
                : "暂未识别到链接"
        }
        if model.supportedLinkCount == 0 {
            return "识别到 \(model.detectedLinks.count) 个链接，但没有支持的平台"
        }
        if model.detectedLinks.count == 1, let link = model.detectedLinks.first {
            return "已识别为 \(link.platform.displayName)"
        }

        var result = "已识别 \(model.supportedLinkCount) 个可下载链接"
        if model.unsupportedLinkCount > 0 {
            result += "，\(model.unsupportedLinkCount) 个不支持"
        }
        return result
    }

    private var visibleStatus: String {
        if model.isParsing {
            return "正在检查链接…"
        }
        if model.isWorking && model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return model.status
        }
        if model.statusIsError || !model.validatedInput.isEmpty {
            return model.status
        }
        return platformStatus
    }

    private var statusDetail: String {
        if model.isParsing {
            return "正在确认下载环境与平台可用性"
        }
        if model.isWorking && model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "后台 \(model.activeTaskCount) 个任务等待或正在下载，可继续粘贴下一批链接"
        }
        if model.statusIsError {
            return "请检查链接内容、平台支持或下载环境"
        }
        if !model.validatedInput.isEmpty {
            return "下载环境已就绪，可以开始下载"
        }
        if model.supportedLinkCount > 0 {
            let xhs = platformCount(for: .xiaohongshu)
            let douyin = platformCount(for: .douyin)
            return "小红书 \(xhs) · 抖音 \(douyin)"
        }
        return "支持小红书与抖音，多条链接可批量处理"
    }

    private var downloadButtonTitle: String {
        if model.isWorking {
            return model.supportedLinkCount > 1
                ? "加入任务 \(model.supportedLinkCount) 项"
                : "加入任务"
        }
        return model.supportedLinkCount > 1
            ? "开始下载 \(model.supportedLinkCount) 项"
            : "开始下载"
    }

    private var statusSymbol: String {
        if model.statusIsError { return "exclamationmark.triangle.fill" }
        if !model.validatedInput.isEmpty { return "checkmark.circle.fill" }
        if model.supportedLinkCount > 0 { return "link" }
        return "link"
    }

    private var statusColor: Color {
        if model.statusIsError { return CoreColor.danger }
        if !model.validatedInput.isEmpty { return CoreColor.success }
        if model.supportedLinkCount > 0 { return CoreColor.accent }
        return CoreColor.textSecondary
    }

    private func platformCount(for platform: DownloadPlatform) -> Int {
        model.detectedLinks.filter { $0.platform == platform }.count
    }

    private func validate() {
        Task { await model.validateEngine() }
    }

    private func download() {
        Task { await model.runDownload() }
    }
}
#endif
