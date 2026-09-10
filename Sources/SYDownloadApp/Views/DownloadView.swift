#if canImport(SwiftUI)
import SwiftUI
import SYDownloadCore

struct DownloadView: View {
    @ObservedObject var model: AppModel
    @FocusState private var linkEditorFocused: Bool

    var body: some View {
        PageContainer(title: "下载") {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
                    composer
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, DesignSystem.spaceL)
            }
        }
        .onChange(of: model.input) { _, _ in model.detectLocally() }
        .onReceive(NotificationCenter.default.publisher(for: .syDownloadFocusDownloadInput)) { _ in
            linkEditorFocused = true
        }
        .tint(DesignSystem.accent)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceM) {
            Text("下载链接")
                .syTypography(DesignSystem.typographySectionTitle)
                .foregroundStyle(DesignSystem.textPrimary)

            TextField("粘贴一个或多个链接 / 完整分享文本…", text: $model.input, axis: .vertical)
                .textFieldStyle(.plain)
                .font(DesignSystem.bodyFont)
                .lineLimit(8...12)
                .padding(.horizontal, DesignSystem.controlHorizontalPadding)
                .padding(.vertical, DesignSystem.spaceS)
                .frame(height: DesignSystem.downloadComposerHeight, alignment: .topLeading)
                .syInputSurface(
                    isFocused: linkEditorFocused,
                    isError: inputShowsError
                )
                .focused($linkEditorFocused)
                .accessibilityLabel("下载链接")

            HStack(spacing: DesignSystem.spaceS) {
                Text("每行一个链接，也可以直接粘贴完整分享文本")
                    .syTypography(DesignSystem.typographyCaption)
                    .foregroundStyle(DesignSystem.textTertiary)

                Spacer(minLength: DesignSystem.spaceM)

                if !model.input.isEmpty {
                    Button("清空", systemImage: "xmark", action: model.clearInput)
                        .buttonStyle(.borderless)
                        .font(DesignSystem.uiFont)
                        .frame(height: DesignSystem.controlHeightCompact)
                        .foregroundStyle(DesignSystem.textSecondary)
                }
            }

            HStack(spacing: DesignSystem.spaceS) {
                platformChip(.xiaohongshu)
                platformChip(.douyin)
                Spacer(minLength: 0)
            }

            statusPanel

            HStack(spacing: DesignSystem.spaceM) {
                Spacer(minLength: 0)

                Button("检查链接", systemImage: "checkmark.circle", action: validate)
                    .buttonStyle(.bordered)
                    .font(DesignSystem.uiFont)
                    .frame(height: DesignSystem.controlHeightDefault)
                    .disabled(actionsDisabled)

                Button(downloadButtonTitle, systemImage: "arrow.down", action: download)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .font(DesignSystem.uiFont)
                    .frame(height: DesignSystem.controlHeightLarge)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(actionsDisabled)
            }
        }
    }

    private func platformChip(_ platform: DownloadPlatform) -> some View {
        let count = platformCount(for: platform)
        let active = count > 0

        return HStack(spacing: DesignSystem.spaceXS) {
            PlatformBrandIcon(platform: platform, size: 16, cornerRadius: 4)

            Text(platform.displayName)
                .syTypography(DesignSystem.typographyGroupLabel)

            Text("\(count)")
                .syTypography(DesignSystem.typographyGroupLabel)
                .monospacedDigit()
                .foregroundStyle(active ? DesignSystem.accent : DesignSystem.textTertiary)
                .padding(.horizontal, DesignSystem.spaceXS)
                .background(
                    active ? DesignSystem.selectionBackground : DesignSystem.panelBackground,
                    in: Capsule()
                )
        }
        .foregroundStyle(active ? DesignSystem.textPrimary : DesignSystem.textSecondary)
        .padding(.horizontal, DesignSystem.spaceS)
        .frame(minHeight: DesignSystem.controlHeightCompact)
        .background(
            active ? DesignSystem.selectionBackground : DesignSystem.controlBackground,
            in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
                .strokeBorder(
                    active ? DesignSystem.accent.opacity(0.18) : DesignSystem.divider,
                    lineWidth: DesignSystem.dividerWidth
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(platform.displayName) \(count) 个链接")
    }

    private var statusPanel: some View {
        HStack(spacing: DesignSystem.spaceM) {
            if model.isParsing || model.isWorking {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: DesignSystem.controlIconSize, height: DesignSystem.controlIconSize)
            } else {
                Image(systemName: statusSymbol)
                    .font(.system(size: DesignSystem.controlIconSize, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .frame(width: DesignSystem.controlIconSize, height: DesignSystem.controlIconSize)
            }

            VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                Text(visibleStatus)
                    .syTypography(DesignSystem.typographyControl)
                    .foregroundStyle(model.statusIsError ? DesignSystem.semanticDanger : DesignSystem.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(statusDetail)
                    .syTypography(DesignSystem.typographyCaption)
                    .foregroundStyle(DesignSystem.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: DesignSystem.spaceM)

            if model.supportedLinkCount > 0 {
                Text("\(model.supportedLinkCount) 项")
                    .syTypography(DesignSystem.typographyGroupLabel)
                    .foregroundStyle(DesignSystem.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, DesignSystem.spaceM)
        .padding(.vertical, DesignSystem.spaceS)
        .frame(maxWidth: .infinity, minHeight: RefinementLayout.downloadStatusMinHeight, alignment: .leading)
        .background(
            statusColor.opacity(model.statusIsError || model.supportedLinkCount > 0 ? 0.07 : 0.04),
            in: RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous)
                .strokeBorder(statusColor.opacity(0.14), lineWidth: DesignSystem.dividerWidth)
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
        if model.statusIsError { return DesignSystem.semanticDanger }
        if !model.validatedInput.isEmpty || model.supportedLinkCount > 0 {
            return DesignSystem.semanticSuccess
        }
        return DesignSystem.textSecondary
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
