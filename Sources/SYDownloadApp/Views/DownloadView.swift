#if canImport(SwiftUI)
import SwiftUI
import SYDownloadCore

struct DownloadView: View {
    @ObservedObject var model: AppModel
    @FocusState private var linkEditorFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.spaceXL) {
                header
                composer
                statusLine
            }
            .padding(.horizontal, DesignSystem.contentPadding)
            .padding(.top, DesignSystem.contentPadding)
            .padding(.bottom, DesignSystem.space2XL)
            .frame(maxWidth: DesignSystem.pageMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .onChange(of: model.input) { _, _ in model.detectLocally() }
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
                .font(.headline)

            TextField("粘贴链接或完整分享文本…", text: $model.input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(8...12)
                .focused($linkEditorFocused)
                .accessibilityLabel("下载链接")

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
                    .font(.callout)
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
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: DesignSystem.spaceS)

            if let engine = model.lastDetails["engine"] {
                Text(URL(fileURLWithPath: engine).lastPathComponent)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, DesignSystem.spaceXS)
        .accessibilityElement(children: .combine)
    }

    private var statusSymbol: String {
        if model.statusIsError { return "exclamationmark.triangle.fill" }
        if model.detectedPlatform == .unknown { return "info.circle" }
        return model.validatedInput.isEmpty ? "link" : "checkmark.circle.fill"
    }

    private var statusColor: Color {
        if model.statusIsError { return DesignSystem.destructive }
        if model.detectedPlatform == .unknown { return .secondary }
        return model.validatedInput.isEmpty ? DesignSystem.accent : DesignSystem.success
    }

    private func validate() {
        Task { await model.validateEngine() }
    }

    private func download() {
        Task { await model.runDownload() }
    }
}
#endif
