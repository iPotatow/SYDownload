#if canImport(SwiftUI)
import SwiftUI
import AppKit
import SYDownloadCore

struct DownloadView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.sectionSpacing) {
                HStack(alignment: .top, spacing: DesignSystem.spaceXL) {
                    PageHeader(
                        eyebrow: "QUICK CAPTURE",
                        title: "把链接交给它，剩下的交给引擎。",
                        subtitle: "粘贴小红书、抖音或 TikTok 的分享链接。识别、检查和下载都在同一个工作台完成。",
                        systemImage: "arrow.down.circle"
                    )

                    Spacer(minLength: 0)
                    engineSummary
                }

                linkComposer

                if let preview = model.preview {
                    PreviewCard(preview: preview)
                        .transition(previewTransition)
                }

                saveLocation
                statusLine
            }
            .padding(.horizontal, DesignSystem.contentPadding)
            .padding(.top, DesignSystem.pageHeaderTop)
            .padding(.bottom, DesignSystem.space3XL)
            .frame(maxWidth: DesignSystem.pageMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .onChange(of: model.input) { _, _ in model.detectLocally() }
        .animation(previewAnimation, value: model.preview)
    }

    private var engineSummary: some View {
        SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 11) {
                Text("下载引擎")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Circle()
                        .fill(DesignSystem.accent)
                        .frame(width: 8, height: 8)
                    Text("本地 Bridge")
                        .font(.subheadline.weight(.semibold))
                }
                Divider()
                Text("支持的平台")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                HStack(spacing: 6) {
                    PlatformChip(platform: .xiaohongshu)
                    PlatformChip(platform: .douyin)
                }
            }
        }
        .frame(width: 238)
    }

    private var linkComposer: some View {
        SurfaceCard(padding: 22) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("添加分享链接")
                            .font(.headline.weight(.semibold))
                        Text("支持短链接、完整分享文本和多行内容")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !model.input.isEmpty {
                        Button("清空", systemImage: "xmark.circle.fill", action: model.clearInput)
                            .labelStyle(.iconOnly)
                            .buttonStyle(.plain)
                            .foregroundStyle(.tertiary)
                            .help("清空链接")
                    }
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $model.input)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .frame(minHeight: 142, maxHeight: 180)
                        .background(
                            DesignSystem.warmSurface,
                            in: RoundedRectangle(cornerRadius: DesignSystem.controlRadius, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignSystem.controlRadius, style: .continuous)
                                .stroke(model.detectedPlatform == .unknown ? DesignSystem.hairline : DesignSystem.accent.opacity(0.42), lineWidth: 1)
                        }

                    if model.input.isEmpty {
                        Text("粘贴链接或完整分享文本…")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }

                HStack(spacing: 9) {
                    PlatformChip(platform: .xiaohongshu, selected: model.detectedPlatform == .xiaohongshu)
                    PlatformChip(platform: .douyin, selected: model.detectedPlatform == .douyin || model.detectedPlatform == .tiktok)

                    Spacer(minLength: 16)

                    Button("检查链接", systemImage: "checkmark.circle", action: validate)
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.return, modifiers: [.command])
                        .disabled(
                            model.detectedPlatform == .unknown
                                || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || model.isParsing
                        )

                    Button("开始下载", systemImage: "arrow.down", action: download)
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || model.detectedPlatform == .unknown
                                || model.isWorking
                        )
                }
            }
        }
    }

    private var saveLocation: some View {
        SurfaceCard(padding: 18) {
            HStack(spacing: 13) {
                IconBadge(systemImage: "folder", tint: .secondary, size: 38)
                VStack(alignment: .leading, spacing: 5) {
                    Text("保存位置")
                        .font(.subheadline.weight(.semibold))
                    Text("下载内容会写入这个文件夹")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 18)
                TextField("下载目录", text: $model.outputDirectory)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 260, maxWidth: 460)
                Button("选择…", action: chooseFolder)
                    .buttonStyle(.bordered)
            }
        }
    }

    private var statusLine: some View {
        HStack(spacing: 9) {
            Image(systemName: statusSymbol)
                .foregroundStyle(statusColor)
            Text(model.status)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 12)
            if let engine = model.lastDetails["engine"] {
                Text(URL(fileURLWithPath: engine).lastPathComponent)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 4)
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

    private var previewAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.34, dampingFraction: 1.0)
    }

    private var previewTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985, anchor: .top))
    }

    private func validate() {
        Task { await model.validateEngine() }
    }

    private func download() {
        Task { await model.runDownload() }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择下载保存位置"
        panel.prompt = "选择"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url { model.outputDirectory = url.path }
    }
}

private struct PreviewCard: View {
    let preview: ParsedPreview

    var body: some View {
        SurfaceCard(padding: 20) {
            HStack(alignment: .top, spacing: 16) {
                PlatformThumbnail(platform: preview.platform, size: 68)

                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .top, spacing: 9) {
                        Text(preview.title)
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)
                        Spacer(minLength: 0)
                        PlatformChip(platform: preview.platform, selected: true)
                    }

                    Text(preview.author)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 18) {
                        previewMetadata("类型", "自动识别")
                        previewMetadata("状态", "可下载")
                        previewMetadata("配置", "使用设置页参数")
                    }

                    Text(preview.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func previewMetadata(_ label: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(label).foregroundStyle(.tertiary)
            Text(value).foregroundStyle(.primary)
        }
        .font(.caption)
    }
}
#endif
