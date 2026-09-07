#if canImport(SwiftUI)
import SwiftUI
import AppKit
import XDownloaderCore

struct DownloadView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                pageHeader
                linkComposer

                if let preview = model.preview {
                    PreviewCard(preview: preview)
                        .transition(previewTransition)
                }

                saveLocation

                if model.detectedPlatform != .unknown || !model.status.isEmpty {
                    statusLine
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 28)
            .padding(.bottom, 36)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .onChange(of: model.input) { _, _ in model.detectLocally() }
        .animation(previewAnimation, value: model.preview)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("下载")
                .font(.largeTitle.weight(.bold))
            Text("粘贴小红书或抖音分享链接，应用会自动识别平台并调用对应引擎。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 620, alignment: .leading)
        }
    }

    private var linkComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.input)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 122, maxHeight: 160)
                    .background(
                        Color(nsColor: .textBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                if model.input.isEmpty {
                    Text("粘贴链接或完整分享文本…")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 14))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 19)
                        .allowsHitTesting(false)
                }

                if !model.input.isEmpty {
                    HStack {
                        Spacer()
                        Button { model.clearInput() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help("清空")
                        .padding(12)
                    }
                }
            }

            HStack(spacing: 8) {
                PlatformChip(platform: .xiaohongshu, selected: model.detectedPlatform == .xiaohongshu)
                PlatformChip(platform: .douyin, selected: model.detectedPlatform == .douyin || model.detectedPlatform == .tiktok)

                Spacer(minLength: 18)

                Button {
                    Task { await model.validateEngine() }
                } label: {
                    HStack(spacing: 6) {
                        if model.isParsing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.circle")
                        }
                        Text(model.isParsing ? "解析中…" : "解析")
                    }
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(
                    model.detectedPlatform == .unknown
                        || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || model.isParsing
                )

                Button {
                    Task { await model.runDownload() }
                } label: {
                    HStack(spacing: 6) {
                        if model.isWorking {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: "arrow.down")
                        }
                        Text(model.isWorking ? "下载中…" : "开始下载")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || model.detectedPlatform == .unknown
                        || model.isWorking
                )
            }
        }
    }

    private var saveLocation: some View {
        GroupBox {
            HStack(spacing: 10) {
                TextField("下载目录", text: $model.outputDirectory)
                    .textFieldStyle(.roundedBorder)
                Button("选择…") { chooseFolder() }
                    .buttonStyle(.bordered)
            }
            .padding(.top, 2)
        } label: {
            Label("保存位置", systemImage: "folder")
                .font(.system(size: 13, weight: .semibold))
        }
    }

    private var statusLine: some View {
        HStack(spacing: 8) {
            Image(systemName: model.detectedPlatform == .unknown ? "info.circle" : "checkmark.circle.fill")
                .foregroundStyle(model.detectedPlatform == .unknown ? Color.secondary : Color.green)
            Text(model.status)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 12)
            if let engine = model.lastDetails["engine"] {
                Text(URL(fileURLWithPath: engine).lastPathComponent)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.system(size: 13))
    }

    private var previewAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : .spring(response: 0.34, dampingFraction: 1.0)
    }

    private var previewTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.985, anchor: .top))
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
        HStack(alignment: .top, spacing: 16) {
            PlatformThumbnail(platform: preview.platform, size: 58)

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Text(preview.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(2)
                    PlatformChip(platform: preview.platform, selected: true)
                }

                Text(preview.author)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 18) {
                    metadata("类型", "自动识别")
                    metadata("状态", "可下载")
                    metadata("配置", "使用设置页参数")
                }

                Text(preview.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .designCard()
    }

    private func metadata(_ label: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .foregroundStyle(.tertiary)
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.system(size: 12))
    }
}
#endif
