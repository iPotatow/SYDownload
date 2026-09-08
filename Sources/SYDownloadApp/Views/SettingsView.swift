#if canImport(SwiftUI)
import SwiftUI
import AppKit
import Combine

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "通用"
    case xhs = "小红书"
    case douyin = "抖音"
    case advanced = "高级"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .xhs: return "book.pages"
        case .douyin: return "music.note"
        case .advanced: return "wrench.and.screwdriver"
        }
    }

    var description: String {
        switch self {
        case .general: return "应用行为、外观和默认保存位置"
        case .xhs: return "小红书内容类型、格式和 Cookie"
        case .douyin: return "抖音内容和文件管理"
        case .advanced: return "路径、原始配置和恢复操作"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var tab: SettingsTab = .general
    @AppStorage("preferredAppearance") private var preferredAppearance = "跟随系统"
    @State private var resetTarget: String?
    @State private var observingEngineSettingsChanges = false
    @SceneStorage("SYDownload.settings.xhsDirty") private var xhsSettingsDirty = false
    @SceneStorage("SYDownload.settings.douyinDirty") private var douyinSettingsDirty = false
    private let fieldWidth: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
            PageHeader(
                title: "设置",
                subtitle: "调整保存位置、下载内容和引擎行为。"
            )

            settingsTabs
            statusBanner
            settingsContent
            saveBarForCurrentTab
        }
        .padding(.horizontal, DesignSystem.contentPadding)
        .padding(.top, DesignSystem.contentPadding)
        .padding(.bottom, DesignSystem.spaceL)
        .frame(maxWidth: DesignSystem.pageMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .tint(DesignSystem.accent)
        .preferredColorScheme(preferredAppearance == "浅色" ? .light : preferredAppearance == "深色" ? .dark : nil)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: tab)
        .task {
            let isInitialLoad = !model.hasLoadedEngineSettings
            observingEngineSettingsChanges = false
            await model.loadEngineSettings()
            if isInitialLoad && model.hasLoadedEngineSettings {
                xhsSettingsDirty = false
                douyinSettingsDirty = false
            }
            observingEngineSettingsChanges = true
        }
        .onReceive(model.$xhsSettings.dropFirst()) { _ in
            guard observingEngineSettingsChanges, !model.settingsLoading else { return }
            xhsSettingsDirty = true
        }
        .onReceive(model.$douyinSettings.dropFirst()) { _ in
            guard observingEngineSettingsChanges, !model.settingsLoading else { return }
            douyinSettingsDirty = true
        }
        .alert("恢复默认配置？", isPresented: Binding(
            get: { resetTarget != nil },
            set: { if !$0 { resetTarget = nil } }
        )) {
            Button("取消", role: .cancel) { resetTarget = nil }
            Button("恢复默认", role: .destructive) {
                let target = resetTarget
                self.resetTarget = nil
                if let target {
                    Task {
                        await model.resetEngineSettings(target)
                        guard !model.settingsStatusIsError else { return }
                        if target == "xiaohongshu" {
                            xhsSettingsDirty = false
                        } else if target == "douyin" {
                            douyinSettingsDirty = false
                        }
                    }
                }
            }
        } message: {
            Text("这会覆盖当前引擎中已保存的对应设置，并重新读取内置默认值。")
        }
    }

    private var settingsTabs: some View {
        Picker("设置分类", selection: $tab) {
            ForEach(SettingsTab.allCases) { item in
                Label(item.rawValue, systemImage: item.systemImage)
                    .tag(item)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("设置分类")
    }

    private var settingsContent: some View {
        Form {
            switch tab {
            case .general: generalSettings
            case .xhs: xhsSettings
            case .douyin: douyinSettings
            case .advanced: advancedSettings
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .formStyle(.grouped)
        .disabled(model.settingsLoading)
        .opacity(model.settingsLoading ? 0.68 : 1)
    }

    @ViewBuilder
    private var statusBanner: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.spaceS) {
            Text(tab.description)
                .font(DesignSystem.supportingFont)
                .foregroundStyle(.secondary)
            Spacer(minLength: DesignSystem.spaceM)
            if model.settingsLoading {
                ProgressView().controlSize(.small)
                Text("正在同步配置")
            } else if !model.settingsStatus.isEmpty {
                Label(model.settingsStatus, systemImage: model.settingsStatusIsError ? "exclamationmark.triangle" : "checkmark.circle")
                    .foregroundStyle(model.settingsStatusIsError ? DesignSystem.destructive : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if model.settingsStatusIsError {
                    Button("重新读取") {
                        Task {
                            observingEngineSettingsChanges = false
                            await model.loadEngineSettings(force: true)
                            if model.hasLoadedEngineSettings && !model.settingsStatusIsError {
                                xhsSettingsDirty = false
                                douyinSettingsDirty = false
                            }
                            observingEngineSettingsChanges = true
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .font(.callout)
    }

    @ViewBuilder
    private var generalSettings: some View {
        Section("保存位置") {
            HStack(spacing: DesignSystem.spaceS) {
                TextField("下载目录", text: $model.outputDirectory)
                    .textFieldStyle(.roundedBorder)
                Button("更改") { chooseFolder() }
            }
            Text("下载时会同步到小红书的 work_path 与抖音的 root。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("偏好") {
            LabeledContent("应用外观") {
                Picker("", selection: $preferredAppearance) {
                    ForEach(["跟随系统", "浅色", "深色"], id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
                .labelsHidden()
                .frame(width: fieldWidth)
            }
        }
    }

    @ViewBuilder
    private var xhsSettings: some View {
        Section("下载内容") {
            Toggle("下载图片", isOn: $model.xhsSettings.imageDownload)
            Toggle("下载视频", isOn: $model.xhsSettings.videoDownload)
            Toggle("下载动图", isOn: $model.xhsSettings.liveDownload)
        }

        Section("格式") {
            LabeledContent("图片格式") {
                Picker("", selection: $model.xhsSettings.imageFormat) {
                    ForEach(["JPEG", "PNG", "WEBP", "HEIC", "AUTO"], id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
                .labelsHidden()
                .frame(width: fieldWidth)
            }
            LabeledContent("视频偏好") {
                Picker("", selection: $model.xhsSettings.videoPreference) {
                    Text("分辨率优先").tag("resolution")
                    Text("码率优先").tag("bitrate")
                    Text("文件大小优先").tag("size")
                }
                .labelsHidden()
                .frame(width: fieldWidth)
            }
            LabeledContent("作品信息格式") {
                Picker("", selection: $model.xhsSettings.noteFormat) {
                    Text("不保存").tag("")
                    Text("TXT").tag("txt")
                    Text("Markdown").tag("md")
                    Text("全部").tag("all")
                }
                .labelsHidden()
                .frame(width: fieldWidth)
            }
        }

        Section("文件管理") {
            LabeledContent("文件夹名称") {
                TextField("", text: $model.xhsSettings.folderName)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: fieldWidth)
            }
            LabeledContent("文件命名格式") {
                TextField("发布时间 作者昵称 作品标题", text: $model.xhsSettings.nameFormat)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: fieldWidth)
            }
            Divider()
            Toggle("每个作品使用独立文件夹", isOn: $model.xhsSettings.folderMode)
                .toggleStyle(.switch)
            Toggle("按作者归档", isOn: $model.xhsSettings.authorArchive)
                .toggleStyle(.switch)
            Toggle("记录下载历史", isOn: $model.xhsSettings.downloadRecord)
                .toggleStyle(.switch)
            Toggle("将文件修改时间写为作品发布时间", isOn: $model.xhsSettings.writeMtime)
                .toggleStyle(.switch)
            Toggle("记录作品数据", isOn: $model.xhsSettings.recordData)
                .toggleStyle(.switch)
        }

        Section("Cookie") {
            VStack(alignment: .leading, spacing: DesignSystem.spaceS) {
                Text("小红书网页版 Cookie")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                plainTextEditor(text: $model.xhsSettings.cookie, minHeight: 100)
                    .accessibilityLabel("小红书网页版 Cookie")
            }
        }
    }

    @ViewBuilder
    private var douyinSettings: some View {
        Section("下载内容") {
            Toggle("下载音乐", isOn: $model.douyinSettings.music)
            Toggle("下载动态封面", isOn: $model.douyinSettings.dynamicCover)
            Toggle("下载静态封面", isOn: $model.douyinSettings.staticCover)
            Toggle("优先原始画质", isOn: $model.douyinSettings.originalQuality)
        }

        Section("文件管理") {
            LabeledContent("文件夹名称") {
                TextField("", text: $model.douyinSettings.folderName)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: fieldWidth)
            }
            LabeledContent("文件命名格式") {
                TextField("create_time type nickname desc", text: $model.douyinSettings.nameFormat)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: fieldWidth)
            }
            LabeledContent("描述最大长度") {
                TextField("64", value: $model.douyinSettings.descLength, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: fieldWidth)
            }
            LabeledContent("文件名最大长度") {
                TextField("128", value: $model.douyinSettings.nameLength, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: fieldWidth)
            }
            LabeledContent("日期格式") {
                TextField("%Y-%m-%d %H:%M:%S", text: $model.douyinSettings.dateFormat)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: fieldWidth)
            }
            LabeledContent("文件名分隔符") {
                TextField("-", text: $model.douyinSettings.split)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: fieldWidth)
            }
            LabeledContent("数据保存格式") {
                TextField("留空为不保存", text: $model.douyinSettings.storageFormat)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: fieldWidth)
            }
            LabeledContent("文件大小限制") {
                HStack(spacing: DesignSystem.spaceS) {
                    TextField("0", value: $model.douyinSettings.maxSize, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: fieldWidth)
                    Text("0 表示不限制")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Toggle("每个作品使用独立文件夹", isOn: $model.douyinSettings.folderMode)
                .toggleStyle(.switch)
        }

        Section("Cookie") {
            VStack(alignment: .leading, spacing: DesignSystem.spaceS) {
                Text("抖音网页版 Cookie（douyin.com）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                plainTextEditor(text: $model.douyinSettings.cookie, minHeight: 90)
                    .accessibilityLabel("抖音网页版 Cookie")
            }
        }
    }

    @ViewBuilder
    private var advancedSettings: some View {
        Section("抖音高级功能") {
            LabeledContent("FFmpeg 路径") {
                TextField("留空使用上游默认行为", text: $model.douyinSettings.ffmpeg)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: fieldWidth)
            }
            LabeledContent("直播画质") {
                TextField("留空使用默认画质", text: $model.douyinSettings.liveQualities)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: fieldWidth)
            }
        }

        Section("原始配置文件") {
            configRow(title: "小红书 settings.json", path: model.xhsSettingsPath)
            configRow(title: "抖音 settings.json", path: model.douyinSettingsPath)
            Text("App 只修改界面中可见的字段。代理、网络超时、重试、浏览器指纹等未展示字段会原样保留在原始 JSON 中。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("恢复默认配置") {
            Text("恢复后会重新读取当前内置版本的上游默认 settings.json。")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: DesignSystem.spaceS) {
                Button("恢复小红书默认设置", role: .destructive) { resetTarget = "xiaohongshu" }
                Button("恢复抖音默认设置", role: .destructive) { resetTarget = "douyin" }
            }
        }

        Section("数据目录") {
            pathRow("应用数据", "~/Library/Application Support/SYDownload/")
            pathRow("缓存", "~/Library/Caches/SYDownload/")
            pathRow("下载文件", model.outputDirectory)
        }
    }

    private func saveBar(
        title: String,
        isDirty: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: DesignSystem.spaceM) {
            VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                Label(
                    isDirty ? "有未保存更改" : "当前配置已保存",
                    systemImage: isDirty ? "circle.fill" : "checkmark.circle"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(isDirty ? DesignSystem.accent : .secondary)

                Text("保存时只合并当前页面管理的字段，不会覆盖隐藏配置。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: DesignSystem.spaceM)
            Button(title, action: action)
                .buttonStyle(.borderedProminent)
                .disabled(model.settingsLoading || !isDirty)
        }
        .padding(.vertical, DesignSystem.spaceS)
    }

    @ViewBuilder
    private var saveBarForCurrentTab: some View {
        switch tab {
        case .general:
            EmptyView()
        case .xhs:
            saveBar(title: "保存小红书设置", isDirty: xhsSettingsDirty, action: saveXHSSettings)
        case .douyin:
            saveBar(title: "保存抖音设置", isDirty: douyinSettingsDirty, action: saveDouyinSettings)
        case .advanced:
            saveBar(title: "保存高级设置", isDirty: douyinSettingsDirty, action: saveDouyinSettings)
        }
    }

    private func saveXHSSettings() {
        Task {
            await model.saveXHSSettings()
            if !model.settingsStatusIsError {
                xhsSettingsDirty = false
            }
        }
    }

    private func saveDouyinSettings() {
        Task {
            await model.saveDouyinSettings()
            if !model.settingsStatusIsError {
                douyinSettingsDirty = false
            }
        }
    }

    private func plainTextEditor(text: Binding<String>, minHeight: CGFloat) -> some View {
        TextEditor(text: text)
            .font(.system(size: 12, design: .monospaced))
            .frame(minHeight: minHeight)
    }

    private func configRow(title: String, path: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceS) {
            Text(title)
                .font(.callout.weight(.medium))
            Text(path.isEmpty ? "尚未生成" : path)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(path.isEmpty ? .secondary : .primary)
                .textSelection(.enabled)
            HStack(spacing: DesignSystem.spaceS) {
                Button("打开") { openConfig(path) }
                    .disabled(path.isEmpty)
                Button("在 Finder 中显示") { revealConfig(path) }
                    .disabled(path.isEmpty)
            }
        }
    }

    private func pathRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
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
        if panel.runModal() == .OK, let url = panel.url {
            model.outputDirectory = url.path
        }
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
