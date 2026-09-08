#if canImport(SwiftUI)
import SwiftUI
import SYDownloadCore

struct DownloadView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var linkEditorFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.spaceXL) {
                header
                composer

                if let preview = model.preview {
                    PreviewCard(preview: preview)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }

                statusLine
            }
            .padding(.horizontal, DesignSystem.contentPadding)
            .padding(.top, DesignSystem.contentPadding)
            .padding(.bottom, DesignSystem.space2XL)
            .frame(maxWidth: DesignSystem.pageMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .onChange(of: model.input) { _, _ in model.detectLocally() }
        .animation(
            reduceMotion ? .easeOut(duration: 0.14) : .spring(response: 0.32, dampingFraction: 1),
            value: model.preview
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("新建下载", systemImage: "plus") {
                    model.clearInput()
                    linkEditorFocused = true
                }
                .help("新建下载")
            }
        }
        .tint(DesignSystem.accent)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DesignSystem.spaceL) {
            PageHeader(
                title: "下载",
                subtitle: "粘贴链接即可开始下载，支持小红书、抖音与 TikTok。"
            )

            Spacer(minLength: 0)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceM) {
            Text("下载链接")
                .font(DesignSystem.uiFont.weight(.semibold))
            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.input)
                    .accessibilityLabel("下载链接")
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(DesignSystem.spaceM)
                    .frame(minHeight: 190, maxHeight: 240)
                    .focused($linkEditorFocused)
                    .background(
                        DesignSystem.warmSurface,
                        in: RoundedRectangle(cornerRadius: DesignSystem.controlRadius, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.controlRadius, style: .continuous)
                            .stroke(
                                linkEditorFocused ? DesignSystem.accent : DesignSystem.hairline,
                                lineWidth: linkEditorFocused ? 2 : 1
                            )
                    }

                if model.input.isEmpty {
                    Text("粘贴链接或完整分享文本…")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, DesignSystem.spaceL)
                        .padding(.vertical, DesignSystem.spaceL)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: DesignSystem.spaceS) {
                PlatformChip(
                    platform: .xiaohongshu,
                    selected: model.detectedPlatform == .xiaohongshu
                )
                PlatformChip(
                    platform: .douyin,
                    selected: model.detectedPlatform == .douyin || model.detectedPlatform == .tiktok
                )

                Spacer(minLength: DesignSystem.spaceL)

                if !model.input.isEmpty {
                    Button("清空", systemImage: "xmark", action: model.clearInput)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: DesignSystem.spaceM) {
                Label(platformStatus, systemImage: "link")
                    .font(DesignSystem.supportingFont)
                    .foregroundStyle(.secondary)

                Spacer(minLength: DesignSystem.spaceS)

                Button("检查链接", systemImage: "checkmark.circle", action: validate)
                    .buttonStyle(.borderless)
                    .disabled(
                        model.detectedPlatform == .unknown
                            || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || model.isParsing
                    )
            }

            HStack {
                Spacer()
                Button("开始下载", systemImage: "arrow.down", action: download)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(
                        model.detectedPlatform == .unknown
                            || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || model.isWorking
                            || model.isParsing
                    )
            }
        }
    }

    private var platformStatus: String {
        switch model.detectedPlatform {
        case .unknown:
            return model.input.isEmpty ? "等待识别平台" : "暂未识别支持的平台"
        default:
            return "已识别为 \(model.detectedPlatform.displayName)"
        }
    }

    private var statusLine: some View {
        HStack(spacing: DesignSystem.spaceS) {
            if model.isParsing || model.isWorking {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: statusSymbol)
                    .foregroundStyle(statusColor)
            }

            Text(model.status)
                .font(DesignSystem.supportingFont)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: DesignSystem.spaceS)

            if let engine = model.lastDetails["engine"] {
                Text(URL(fileURLWithPath: engine).lastPathComponent)
                    .font(DesignSystem.metadataFont.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, DesignSystem.spaceXS)
        .accessibilityElement(children: .combine)
    }

    private var statusSymbol: String {
        if model.statusIsError { return "exclamationmark.triangle.fill" }
        if model.detectedPlatform == .unknown { return "info.circle" }
        return model.preview == nil ? "link" : "checkmark.circle.fill"
    }

    private var statusColor: Color {
        if model.statusIsError { return DesignSystem.destructive }
        if model.detectedPlatform == .unknown { return .secondary }
        return model.preview == nil ? DesignSystem.accent : DesignSystem.success
    }

    private func validate() {
        Task { await model.validateEngine() }
    }

    private func download() {
        Task { await model.runDownload() }
    }
}

private struct PreviewCard: View {
    let preview: ParsedPreview

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceS) {
            Text("检查结果")
                .font(DesignSystem.sectionTitleFont)

            InsetRow {
                HStack(alignment: .top, spacing: DesignSystem.spaceM) {
                    PlatformThumbnail(platform: preview.platform, size: 48)

                    VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                        Text(preview.title)
                            .font(.headline.weight(.semibold))
                            .lineLimit(2)
                        Text(preview.author)
                            .font(DesignSystem.supportingFont)
                            .foregroundStyle(.secondary)
                        Text(preview.summary)
                            .font(DesignSystem.supportingFont)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: DesignSystem.spaceM)
                    PlatformChip(platform: preview.platform, selected: true)
                }
            }
        }
    }
}
#endif
