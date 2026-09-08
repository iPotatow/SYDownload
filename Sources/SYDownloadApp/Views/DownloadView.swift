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
        .tint(DesignSystem.accent)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DesignSystem.spaceL) {
            PageHeader(
                title: "下载",
                subtitle: "可一次粘贴多个链接或分享文本，支持小红书与抖音。"
            )

            Spacer(minLength: 0)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceM) {
            Text("下载链接")
                .font(.headline)

            TextField("粘贴一个或多个链接 / 完整分享文本…", text: $model.input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(8...12)
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
                        !model.hasSupportedLinks
                            || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || model.isWorking
                            || model.isParsing
                    )
            }

            HStack {
                Spacer()
                Button(downloadButtonTitle, systemImage: "arrow.down", action: download)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(
                        !model.hasSupportedLinks
                            || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || model.isWorking
                            || model.isParsing
                    )
            }
        }
    }

    private var platformStatus: String {
        if model.detectedLinks.isEmpty {
            return model.input.isEmpty ? "等待识别平台" : "暂未识别到链接"
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

    private var downloadButtonTitle: String {
        model.supportedLinkCount > 1
            ? "开始下载 \(model.supportedLinkCount) 项"
            : "开始下载"
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
        if !model.hasSupportedLinks { return "info.circle" }
        return model.validatedInput.isEmpty ? "link" : "checkmark.circle.fill"
    }

    private var statusColor: Color {
        if model.statusIsError { return DesignSystem.destructive }
        if !model.hasSupportedLinks { return .secondary }
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
