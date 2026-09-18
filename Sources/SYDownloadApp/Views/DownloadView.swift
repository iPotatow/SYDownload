#if canImport(SwiftUI)
import SwiftUI
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
        VStack(alignment: .leading, spacing: CoreSpacing.m) {
            Text("下载链接")
                .coreTypography(CoreTypography.sectionTitle)
                .foregroundStyle(CoreColor.textPrimary)

            TextField("粘贴一个或多个链接 / 完整分享文本…", text: $model.input, axis: .vertical)
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
                    Button("清空", systemImage: "xmark", action: model.clearInput)
                        .buttonStyle(.borderless)
                        .font(CoreTypography.controlFont)
                        .frame(height: CoreMetrics.controlHeightCompact)
                        .foregroundStyle(CoreColor.textSecondary)
                }
            }

            HStack(spacing: CoreSpacing.s) {
                platformChip(.xiaohongshu)
                platformChip(.douyin)
                Spacer(minLength: 0)
            }

            statusPanel

            HStack(spacing: CoreSpacing.m) {
                Spacer(minLength: 0)

                Button("检查链接", systemImage: "checkmark.circle", action: validate)
                    .buttonStyle(.bordered)
                    .font(CoreTypography.controlFont)
                    .frame(height: CoreMetrics.controlHeightDefault)
                    .disabled(actionsDisabled)

                Button(downloadButtonTitle, systemImage: "arrow.down", action: download)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .font(CoreTypography.controlFont)
                    .frame(height: CoreMetrics.controlHeightLarge)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(actionsDisabled)
            }
        }
    }

    private func platformChip(_ platform: DownloadPlatform) -> some View {
        let count = platformCount(for: platform)
        let active = count > 0

        return HStack(spacing: CoreSpacing.xs) {
            PlatformBrandIcon(platform: platform, size: 16, cornerRadius: 4)

            Text(platform.displayName)
                .coreTypography(CoreTypography.groupLabel)

            Text("\(count)")
                .coreTypography(CoreTypography.groupLabel)
                .monospacedDigit()
                .foregroundStyle(active ? CoreColor.accent : CoreColor.textTertiary)
                .padding(.horizontal, CoreSpacing.xs)
                .background(
                    active ? CoreColor.selectionBackground : CoreColor.panelBackground,
                    in: Capsule()
                )
        }
        .foregroundStyle(active ? CoreColor.textPrimary : CoreColor.textSecondary)
        .padding(.horizontal, CoreSpacing.s)
        .frame(minHeight: CoreMetrics.controlHeightCompact)
        .background(
            active ? CoreColor.selectionBackground : CoreColor.controlBackground,
            in: RoundedRectangle(cornerRadius: CoreRadius.row, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CoreRadius.row, style: .continuous)
                .strokeBorder(
                    active ? CoreColor.accent.opacity(0.18) : CoreColor.divider,
                    lineWidth: CoreMetrics.dividerWidth
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(platform.displayName) \(count) 个链接")
    }

    private var statusPanel: some View {
        HStack(spacing: CoreSpacing.m) {
            if model.isParsing || model.isWorking {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: CoreMetrics.controlIconSize, height: CoreMetrics.controlIconSize)
            } else {
                Image(systemName: statusSymbol)
                    .font(.system(size: CoreMetrics.controlIconSize, weight: .semibold))
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
        .padding(.horizontal, CoreSpacing.m)
        .padding(.vertical, CoreSpacing.s)
        .frame(maxWidth: .infinity, minHeight: RefinementLayout.downloadStatusMinHeight, alignment: .leading)
        .background(
            statusColor.opacity(model.statusIsError || model.supportedLinkCount > 0 ? 0.07 : 0.04),
            in: RoundedRectangle(cornerRadius: CoreRadius.panel, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CoreRadius.panel, style: .continuous)
                .strokeBorder(statusColor.opacity(0.14), lineWidth: CoreMetrics.dividerWidth)
        }
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
            || model.isWorking
            || model.isParsing
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
        if model.isWorking {
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
        if model.isWorking {
            return "任务会自动进入任务列表，可在那里查看实时进度"
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
        if model.isWorking { return "正在下载…" }
        return model.supportedLinkCount > 1
            ? "开始下载 \(model.supportedLinkCount) 项"
            : "开始下载"
    }

    private var statusSymbol: String {
        if model.statusIsError { return "exclamationmark.triangle.fill" }
        if !model.validatedInput.isEmpty { return "checkmark.circle.fill" }
        if model.supportedLinkCount > 0 { return "checkmark.circle.fill" }
        return "link"
    }

    private var statusColor: Color {
        if model.statusIsError { return CoreColor.danger }
        if !model.validatedInput.isEmpty || model.supportedLinkCount > 0 {
            return CoreColor.success
        }
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
