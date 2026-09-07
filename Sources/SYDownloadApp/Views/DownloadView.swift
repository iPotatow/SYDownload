#if canImport(SwiftUI)
import SwiftUI
import AppKit
import SYDownloadCore

struct DownloadView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var linkEditorFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
                PageHeader(
                    eyebrow: "QUICK CAPTURE",
                    title: "把链接交给它，剩下的交给引擎。",
                    subtitle: "识别、检查和下载都在同一个工作台完成。",
                    systemImage: "arrow.down.circle"
                )

                // The composer owns the page. Supporting context is kept in a
                // narrow rail so the primary action remains obvious at 960px.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: DesignSystem.spaceL) {
                        composerColumn
                        supportRail.frame(width: 208)
                    }
                    VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
                        composerColumn
                        supportRail
                    }
                }
            }
            .padding(.horizontal, DesignSystem.contentPadding)
            .padding(.top, DesignSystem.pageTitlebarClearance + DesignSystem.pageHeaderTop)
            .padding(.bottom, DesignSystem.space2XL)
            .frame(maxWidth: DesignSystem.pageMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .onChange(of: model.input) { _, _ in model.detectLocally() }
        .animation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.34, dampingFraction: 1), value: model.preview)
        .tint(DesignSystem.accent)
    }

    private var composerColumn: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
            SectionGroup("链接工作台", detail: "先粘贴，再检查") { composer }
            if let preview = model.preview {
                PreviewCard(preview: preview)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
            }
            statusLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceM) {
            HStack(alignment: .firstTextBaseline) {
                Text("分享链接").font(.headline.weight(.semibold))
                Spacer(minLength: 8)
                if !model.input.isEmpty {
                    Button("清空", systemImage: "xmark.circle.fill", action: model.clearInput)
                        .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(.tertiary).help("清空链接")
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.input)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(DesignSystem.spaceS)
                    .frame(minHeight: 142, maxHeight: 166)
                    .focused($linkEditorFocused)
                    .background(DesignSystem.warmSurface, in: RoundedRectangle(cornerRadius: DesignSystem.controlRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.controlRadius, style: .continuous)
                            .stroke(linkEditorFocused ? DesignSystem.accent : DesignSystem.hairline, lineWidth: linkEditorFocused ? 2 : 1)
                    }
                if model.input.isEmpty {
                    Text("粘贴链接或完整分享文本…")
                        .font(.body).foregroundStyle(.tertiary)
                        .padding(.horizontal, DesignSystem.spaceL).padding(.vertical, DesignSystem.spaceL)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: DesignSystem.spaceS) {
                PlatformChip(platform: .xiaohongshu, selected: model.detectedPlatform == .xiaohongshu)
                PlatformChip(platform: .douyin, selected: model.detectedPlatform == .douyin || model.detectedPlatform == .tiktok)
                Spacer(minLength: DesignSystem.spaceS)
                Button("检查链接", systemImage: "checkmark.circle", action: validate)
                    .buttonStyle(.bordered).keyboardShortcut(.return, modifiers: [.command])
                    .disabled(model.detectedPlatform == .unknown || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isParsing)
                Button("开始下载", systemImage: "arrow.down", action: download)
                    .buttonStyle(.borderedProminent)
                    .disabled(model.detectedPlatform == .unknown || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isWorking)
            }
        }
        .padding(DesignSystem.panelPadding)
        .background(DesignSystem.panelBackground, in: RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous).strokeBorder(DesignSystem.hairline) }
        .shadow(color: DesignSystem.shadow, radius: 12, y: 4)
    }

    private var supportRail: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceM) {
            SectionGroup("引擎", detail: "本地优先") {
                VStack(alignment: .leading, spacing: DesignSystem.spaceS) {
                    Label("Bridge 就绪", systemImage: "checkmark.circle.fill").foregroundStyle(DesignSystem.accent)
                    Text("链接和配置只在本机处理。").font(DesignSystem.supportingFont).foregroundStyle(.secondary)
                }
                .padding(DesignSystem.spaceM)
                .background(DesignSystem.rowBackground, in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous))
            }
            SectionGroup("支持平台") {
                VStack(alignment: .leading, spacing: 4) {
                    PlatformChip(platform: .xiaohongshu)
                    PlatformChip(platform: .douyin)
                    PlatformChip(platform: .tiktok)
                }
            }
            SectionGroup("保存到") {
                VStack(alignment: .leading, spacing: DesignSystem.spaceS) {
                    Label("下载目录", systemImage: "folder").font(DesignSystem.uiFont)
                    Text(model.outputDirectory).font(DesignSystem.metadataFont.monospaced()).foregroundStyle(.secondary).lineLimit(2).truncationMode(.middle)
                    Button("更改位置", systemImage: "arrow.up.right", action: chooseFolder).buttonStyle(.borderless)
                }
                .padding(DesignSystem.spaceM)
                .background(DesignSystem.rowBackground, in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous))
            }
        }
    }

    private var statusLine: some View {
        HStack(spacing: DesignSystem.spaceS) {
            Image(systemName: statusSymbol).foregroundStyle(statusColor)
            Text(model.status).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            Spacer(minLength: 8)
            if let engine = model.lastDetails["engine"] {
                Text(URL(fileURLWithPath: engine).lastPathComponent).font(DesignSystem.metadataFont.monospaced()).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, DesignSystem.spaceS)
        .accessibilityElement(children: .combine)
    }

    private var statusSymbol: String {
        if model.isParsing || model.isWorking { return "arrow.triangle.2.circlepath" }
        if model.detectedPlatform == .unknown { return "info.circle" }
        return model.preview == nil ? "link" : "checkmark.circle.fill"
    }

    private var statusColor: Color {
        if model.detectedPlatform == .unknown { return .secondary }
        return model.preview == nil ? DesignSystem.accent : DesignSystem.success
    }

    private func validate() { Task { await model.validateEngine() } }
    private func download() { Task { await model.runDownload() } }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择下载保存位置"; panel.prompt = "选择"
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false; panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url { model.outputDirectory = url.path }
    }
}

private struct PreviewCard: View {
    let preview: ParsedPreview

    var body: some View {
        SectionGroup("解析结果", detail: "可以开始下载") {
            HStack(alignment: .top, spacing: DesignSystem.spaceM) {
                PlatformThumbnail(platform: preview.platform, size: 56)
                VStack(alignment: .leading, spacing: DesignSystem.spaceS) {
                    HStack(alignment: .firstTextBaseline, spacing: DesignSystem.spaceS) {
                        Text(preview.title).font(.title3.weight(.semibold)).lineLimit(2)
                        Spacer(minLength: 0)
                        PlatformChip(platform: preview.platform, selected: true)
                    }
                    Text(preview.author).font(.subheadline).foregroundStyle(.secondary)
                    Text(preview.summary).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DesignSystem.panelPadding)
            .background(DesignSystem.rowBackground, in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous))
        }
    }
}
#endif
