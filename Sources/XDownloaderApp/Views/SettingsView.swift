#if canImport(SwiftUI)
import SwiftUI
import AppKit

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "通用"
    case xhs = "小红书"
    case douyin = "抖音"
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
        ScrollView {
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
                    case .xhs: xhsSettings
                    case .douyin: douyinSettings
                    case .advanced: advancedSettings
                    }
                }

                if model.settingsLoading {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("正在同步原始项目配置…")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                } else if !model.settingsStatus.isEmpty {
                    Label(model.settingsStatus, systemImage: "info.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .task {
            await model.loadEngineSettings()
        }
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingCard("保存位置") {
                HStack(spacing: 10) {
                    TextField("下载目录", text: $model.outputDirectory).textFieldStyle(.roundedBorder)
                    Button("更改") { chooseFolder() }
                }
                Text("下载时会同步到小红书的 work_path 与抖音的 root。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    private var xhsSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingCard("下载内容") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("下载图片", isOn: $model.xhsSettings.imageDownload)
                    Toggle("下载视频", isOn: $model.xhsSettings.videoDownload)
                    Toggle("下载动图", isOn: $model.xhsSettings.liveDownload)
                }
                .toggleStyle(.checkbox)
            }

            settingCard("格式") {
                VStack(spacing: 12) {
                    LabeledContent("图片格式") {
                        Picker("", selection: $model.xhsSettings.imageFormat) {
                            ForEach(["JPEG", "PNG", "WEBP", "HEIC", "AUTO"], id: \.self) { value in
                                Text(value).tag(value)
                            }
                        }
                        .labelsHidden().frame(width: 160)
                    }
                    LabeledContent("视频偏好") {
                        Picker("", selection: $model.xhsSettings.videoPreference) {
                            Text("分辨率优先").tag("resolution")
                            Text("码率优先").tag("bitrate")
                            Text("文件大小优先").tag("size")
                        }
                        .labelsHidden().frame(width: 160)
                    }
                    LabeledContent("作品信息格式") {
                        Picker("", selection: $model.xhsSettings.noteFormat) {
                            Text("不保存").tag("")
                            Text("TXT").tag("txt")
                            Text("Markdown").tag("md")
                            Text("全部").tag("all")
                        }
                        .labelsHidden().frame(width: 160)
                    }
                }
            }

            settingCard("文件管理") {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("文件夹名称") {
                        TextField("Download", text: $model.xhsSettings.folderName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 280)
                    }
                    LabeledContent("文件命名格式") {
                        TextField("发布时间 作者昵称 作品标题", text: $model.xhsSettings.nameFormat)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 360)
                    }
                    Divider()
                    Toggle("每个作品使用独立文件夹", isOn: $model.xhsSettings.folderMode)
                    Toggle("按作者归档", isOn: $model.xhsSettings.authorArchive)
                    Toggle("记录下载历史", isOn: $model.xhsSettings.downloadRecord)
                    Toggle("将文件修改时间写为作品发布时间", isOn: $model.xhsSettings.writeMtime)
                    Toggle("记录作品数据", isOn: $model.xhsSettings.recordData)
                }
                .toggleStyle(.checkbox)
            }

            settingCard("Cookie") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("小红书网页版 Cookie")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    plainTextEditor(text: $model.xhsSettings.cookie, minHeight: 100)
                }
            }

            saveBar(title: "保存小红书设置") {
                Task { await model.saveXHSSettings() }
            }
        }
    }

    private var douyinSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingCard("下载内容") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("下载音乐", isOn: $model.douyinSettings.music)
                    Toggle("下载动态封面", isOn: $model.douyinSettings.dynamicCover)
                    Toggle("下载静态封面", isOn: $model.douyinSettings.staticCover)
                    Toggle("优先原始画质", isOn: $model.douyinSettings.originalQuality)
                }
                .toggleStyle(.checkbox)
            }

            settingCard("文件管理") {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("文件夹名称") {
                        TextField("Download", text: $model.douyinSettings.folderName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 280)
                    }
                    LabeledContent("文件命名格式") {
                        TextField("create_time type nickname desc", text: $model.douyinSettings.nameFormat)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 360)
                    }
                    LabeledContent("描述最大长度") {
                        TextField("64", value: $model.douyinSettings.descLength, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                    }
                    LabeledContent("文件名最大长度") {
                        TextField("128", value: $model.douyinSettings.nameLength, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                    }
                    LabeledContent("日期格式") {
                        TextField("%Y-%m-%d %H:%M:%S", text: $model.douyinSettings.dateFormat)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 280)
                    }
                    LabeledContent("文件名分隔符") {
                        TextField("-", text: $model.douyinSettings.split)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                    }
                    LabeledContent("数据保存格式") {
                        TextField("留空为不保存", text: $model.douyinSettings.storageFormat)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                    }
                    LabeledContent("文件大小限制") {
                        HStack(spacing: 6) {
                            TextField("0", value: $model.douyinSettings.maxSize, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 110)
                            Text("0 表示不限制")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle("每个作品使用独立文件夹", isOn: $model.douyinSettings.folderMode)
                        .toggleStyle(.checkbox)
                }
            }

            settingCard("Cookie") {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("国内链接 Cookie（douyin.com）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        plainTextEditor(text: $model.douyinSettings.cookie, minHeight: 90)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("国际链接 Cookie（tiktok.com）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        plainTextEditor(text: $model.douyinSettings.cookieTikTok, minHeight: 90)
                    }
                }
            }

            saveBar(title: "保存抖音设置") {
                Task { await model.saveDouyinSettings() }
            }
        }
    }

    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingCard("抖音高级功能") {
                VStack(spacing: 12) {
                    LabeledContent("FFmpeg 路径") {
                        TextField("留空使用上游默认行为", text: $model.douyinSettings.ffmpeg)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 360)
                    }
                    LabeledContent("直播画质") {
                        TextField("留空使用默认画质", text: $model.douyinSettings.liveQualities)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 240)
                    }
                    HStack {
                        Spacer()
                        Button("保存高级设置") {
                            Task { await model.saveDouyinSettings() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            settingCard("原始配置文件") {
                VStack(alignment: .leading, spacing: 14) {
                    configRow(title: "小红书 settings.json", path: model.xhsSettingsPath)
                    Divider()
                    configRow(title: "抖音 settings.json", path: model.douyinSettingsPath)
                    Text("App 只修改界面中可见的字段。代理、网络超时、重试、浏览器指纹等未展示字段会原样保留在原始 JSON 中。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            settingCard("恢复默认配置") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("恢复后会重新读取当前内置版本的上游默认 settings.json。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button("恢复小红书默认设置", role: .destructive) {
                            Task { await model.resetEngineSettings("xiaohongshu") }
                        }
                        Button("恢复抖音默认设置", role: .destructive) {
                            Task { await model.resetEngineSettings("douyin") }
                        }
                    }
                }
            }

            settingCard("数据目录") {
                VStack(alignment: .leading, spacing: 10) {
                    pathRow("应用数据", "~/Library/Application Support/SYDownload/")
                    pathRow("缓存", "~/Library/Caches/SYDownload/")
                    pathRow("下载文件", model.outputDirectory)
                }
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

    private func saveBar(title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text("保存时只合并当前页面管理的字段，不会覆盖隐藏配置。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(title, action: action)
                .buttonStyle(.borderedProminent)
                .disabled(model.settingsLoading)
        }
    }

    private func plainTextEditor(text: Binding<String>, minHeight: CGFloat) -> some View {
        TextEditor(text: text)
            .font(.system(size: 12, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(8)
            .frame(minHeight: minHeight)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            }
    }

    private func configRow(title: String, path: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 13, weight: .medium))
            Text(path.isEmpty ? "尚未生成" : path)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(path.isEmpty ? .secondary : .primary)
                .textSelection(.enabled)
            HStack(spacing: 8) {
                Button("打开") { openConfig(path) }
                    .disabled(path.isEmpty)
                Button("在 Finder 中显示") { revealConfig(path) }
                    .disabled(path.isEmpty)
            }
        }
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

    private func openConfig(_ path: String) {
        guard !path.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func revealConfig(_ path: String) {
        guard !path.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}
#endif
