#if canImport(SwiftUI)
import SwiftUI
import AppKit

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "通用"
    case download = "下载"
    case xhs = "小红书"
    case douyin = "抖音/TikTok"
    case advanced = "高级"

    var id: String { rawValue }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel

    @State private var tab: SettingsTab = .general
    @AppStorage("completionNotification") private var completionNotification = true
    @AppStorage("autoOpenDownloadFolder") private var autoOpenDownloadFolder = false
    @AppStorage("concurrentDownloads") private var concurrentDownloads = 3
    @AppStorage("preferredAppearance") private var preferredAppearance = "跟随系统"
    @AppStorage("preferredLanguage") private var preferredLanguage = "简体中文"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置").font(.system(size: 28, weight: .bold))

            Picker("设置分类", selection: $tab) {
                ForEach(SettingsTab.allCases) { item in Text(item.rawValue).tag(item) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 610)

            Group {
                switch tab {
                case .general: generalSettings
                case .download: downloadSettings
                case .xhs:
                    engineSettings(title: "小红书引擎", subtitle: "XHS-Downloader 已内置在 App 中，首次使用会复制到 Application Support 后运行。", symbol: "book.pages.fill", accent: .red)
                case .douyin:
                    engineSettings(title: "抖音 / TikTok 引擎", subtitle: "TikTokDownloader / DouK 已内置。部分高级签名能力仍可能依赖下一阶段加入的 Node.js。", symbol: "play.rectangle.fill", accent: .blue)
                case .advanced: advancedSettings
                }
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingCard("保存位置") {
                HStack(spacing: 10) {
                    TextField("下载目录", text: $model.outputDirectory).textFieldStyle(.roundedBorder)
                    Button("更改") { chooseFolder() }
                }
            }

            settingCard("行为") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("下载完成后显示通知", isOn: $completionNotification)
                    Toggle("下载完成后自动打开目录", isOn: $autoOpenDownloadFolder)
                }
                .toggleStyle(.switch)
            }

            settingCard("偏好") {
                VStack(spacing: 12) {
                    LabeledContent("同时下载任务数") {
                        Picker("", selection: $concurrentDownloads) {
                            ForEach(1...5, id: \.self) { count in Text("\(count)").tag(count) }
                        }
                        .labelsHidden().frame(width: 90)
                    }
                    LabeledContent("应用外观") {
                        Picker("", selection: $preferredAppearance) {
                            ForEach(["跟随系统", "浅色", "深色"], id: \.self) { value in Text(value).tag(value) }
                        }
                        .labelsHidden().frame(width: 130)
                    }
                    LabeledContent("语言") {
                        Picker("", selection: $preferredLanguage) {
                            ForEach(["简体中文", "English"], id: \.self) { value in Text(value).tag(value) }
                        }
                        .labelsHidden().frame(width: 130)
                    }
                }
            }
        }
    }

    private var downloadSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingCard("默认下载内容") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("视频（无水印）", isOn: $model.includeVideo)
                    Toggle("封面图片", isOn: $model.includeCover)
                    Toggle("音频（MP3）", isOn: $model.includeAudio)
                    Toggle("文案内容", isOn: $model.includeText)
                }
                .toggleStyle(.checkbox)
            }
            settingCard("任务策略") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("当前版本按真实下载结果更新任务状态。", systemImage: "checkmark.circle")
                    Label("实时字节级进度需要下一阶段让 Python Bridge 持续回传进度事件。", systemImage: "arrow.triangle.2.circlepath")
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            }
        }
    }

    private func engineSettings(title: String, subtitle: String, symbol: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            settingCard(title) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 44, height: 44)
                        .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("已随 App 打包").font(.headline)
                        Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
            }
            settingCard("运行目录") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("~/Library/Application Support/XDownloader/engines/").font(.system(.body, design: .monospaced))
                    Text("签名后的 App Bundle 保持只读，引擎在可写副本中运行。").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingCard("数据目录") {
                VStack(alignment: .leading, spacing: 10) {
                    pathRow("应用数据", "~/Library/Application Support/XDownloader/")
                    pathRow("缓存", "~/Library/Caches/XDownloader/")
                    pathRow("下载文件", model.outputDirectory)
                }
            }
            settingCard("当前构建") {
                VStack(alignment: .leading, spacing: 7) {
                    LabeledContent("Python", value: "3.12（内置）")
                    LabeledContent("XHS-Downloader", value: "固定版本")
                    LabeledContent("TikTokDownloader", value: "固定版本")
                    LabeledContent("Node.js", value: "暂未内置")
                    LabeledContent("ffmpeg", value: "暂未内置")
                }
                .font(.system(size: 13))
            }
        }
    }

    private func settingCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 14, weight: .semibold))
            content()
        }
        .padding(16)
        .designCard()
    }

    private func pathRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
        }
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
#endif
