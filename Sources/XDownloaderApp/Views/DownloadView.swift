#if canImport(SwiftUI)
import SwiftUI
import AppKit
import XDownloaderCore

struct DownloadView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("下载")
                    .font(.system(size: 28, weight: .bold))

                inputCard

                if let preview = model.preview {
                    PreviewCard(preview: preview)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                saveLocationCard

                if model.detectedPlatform != .unknown || !model.status.isEmpty {
                    statusLine
                }

                Button {
                    Task { await model.runDownload() }
                } label: {
                    HStack(spacing: 8) {
                        if model.isWorking {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                        }
                        Text(model.isWorking ? "正在下载…" : "开始下载").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.detectedPlatform == .unknown || model.isWorking)
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .onChange(of: model.input) { _, _ in model.detectLocally() }
        .animation(.easeInOut(duration: 0.18), value: model.preview)
    }

    private var inputCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.input)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 112, maxHeight: 150)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(0.10), lineWidth: 1) }

                if model.input.isEmpty {
                    Text("粘贴小红书 / 抖音链接，支持分享文本")
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
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                    }
                }
            }

            HStack(spacing: 8) {
                PlatformChip(platform: .xiaohongshu, selected: model.detectedPlatform == .xiaohongshu)
                PlatformChip(platform: .douyin, selected: model.detectedPlatform == .douyin || model.detectedPlatform == .tiktok)
                Spacer()
                Button {
                    Task { await model.validateEngine() }
                } label: {
                    HStack(spacing: 7) {
                        if model.isParsing { ProgressView().controlSize(.small) } else { Image(systemName: "sparkles") }
                        Text(model.isParsing ? "解析中…" : "解析链接")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.detectedPlatform == .unknown || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isParsing)
            }
            .padding(.top, 10)
        }
        .padding(12)
        .designCard()
    }

    private var saveLocationCard: some View {
        HStack(spacing: 12) {
            Text("保存到：").foregroundStyle(.secondary)
            TextField("下载目录", text: $model.outputDirectory).textFieldStyle(.roundedBorder)
            Button("更改") { chooseFolder() }.buttonStyle(.bordered)
        }
        .padding(14)
        .designCard()
    }

    private var statusLine: some View {
        HStack(spacing: 8) {
            Image(systemName: model.detectedPlatform == .unknown ? "info.circle" : "checkmark.circle.fill")
                .foregroundStyle(model.detectedPlatform == .unknown ? Color.secondary : Color.green)
            Text(model.status).foregroundStyle(.secondary)
            Spacer()
            if let engine = model.lastDetails["engine"] {
                Text(URL(fileURLWithPath: engine).lastPathComponent)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.system(size: 13))
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 18) {
                PlatformThumbnail(platform: preview.platform, size: 104)
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        Text(preview.title).font(.system(size: 18, weight: .semibold))
                        PlatformChip(platform: preview.platform, selected: true)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.fill").foregroundStyle(.secondary)
                        Text(preview.author).foregroundStyle(.secondary)
                    }
                    .font(.system(size: 13))
                    HStack(spacing: 22) {
                        metadata("类型", "自动识别")
                        metadata("状态", "可下载")
                        metadata("配置", "使用设置页参数")
                    }
                    Text(preview.summary).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(16)
        .designCard()
    }

    private func metadata(_ label: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(label).foregroundStyle(.tertiary)
            Text(value).foregroundStyle(.primary)
        }
        .font(.system(size: 13))
    }
}
#endif
