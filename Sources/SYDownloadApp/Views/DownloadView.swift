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
                .font(DesignSystem.sectionTitleFont)

            TextField("粘贴一个或多个链接 / 完整分享文本…", text: $model.input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(DesignSystem.bodyFont)
                .lineLimit(8...12)
                .frame(height: DesignSystem.downloadComposerHeight, alignment: .topLeading)
                .focused($linkEditorFocused)
                .accessibilityLabel("下载链接")

            HStack(spacing: DesignSystem.spaceS) {
                PlatformChip(
                    platform: .xiaohongshu,
                    selected: model.hasXHSLinks
                )
                PlatformChip(
                    platform: .douyin,
                    selected: model.hasDouyinLinks
                )

                Spacer(minLength: DesignSystem.spaceL)

                if !model.input.isEmpty {
                    Button("清空", systemImage: "xmark", action: model.clearInput)
                        .buttonStyle(.borderless)
                        .font(DesignSystem.uiFont)
                        .frame(height: DesignSystem.controlHeightCompact)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: DesignSystem.spaceM) {
                if shouldShowStatus {
                    statusIndicator
                }

                Spacer(minLength: DesignSystem.spaceM)

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

    private var shouldShowStatus: Bool {
        !model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || model.isParsing
            || model.isWorking
            || !model.validatedInput.isEmpty
            || model.statusIsError
    }

    private var actionsDisabled: Bool {
        !model.hasSupportedLinks
            || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || model.isWorking
            || model.isParsing
    }

    private var platformStatus: String {
        if model.detectedLinks.isEmpty {
            return "暂未识别到链接"
        }
        if model.supportedLinkCount == 0 {
            return "识别到 \(model.detectedLinks.count) 个链接，但没有支持的平台"
        }
        if model.detectedLinks.count == 1, let link = model.detectedLinks.first {
            return "已识别为 \(link.platform.displayName)"
        }

        var result = "已识别 \(model.supportedLinkCount) 个支持链接"
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

    private var downloadButtonTitle: String {
        model.supportedLinkCount > 1
            ? "开始下载 \(model.supportedLinkCount) 项"
            : "开始下载"
    }

    private var statusIndicator: some View {
        HStack(spacing: DesignSystem.spaceS) {
            if model.isParsing || model.isWorking {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: statusSymbol)
                    .foregroundStyle(statusColor)
            }

            Text(visibleStatus)
                .font(DesignSystem.bodyFont)
                .foregroundStyle(model.statusIsError ? DesignSystem.destructive : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let engine = model.lastDetails["engine"], !model.isParsing {
                Text(URL(fileURLWithPath: engine).lastPathComponent)
                    .font(DesignSystem.metadataFont.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var statusSymbol: String {
        if model.statusIsError { return "exclamationmark.triangle.fill" }
        if !model.validatedInput.isEmpty { return "checkmark.circle.fill" }
        return "link"
    }

    private var statusColor: Color {
        if model.statusIsError { return DesignSystem.destructive }
        if !model.validatedInput.isEmpty { return DesignSystem.success }
        return DesignSystem.accent
    }

    private func validate() {
        Task { await model.validateEngine() }
    }

    private func download() {
        Task { await model.runDownload() }
    }
}
#endif
