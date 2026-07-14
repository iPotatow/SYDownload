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
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var updater: SYDownloadUpdater
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var tab: SettingsTab = .general
    @AppStorage("preferredAppearance") private var preferredAppearance = "跟随系统"
    @State private var resetTarget: String?
    @State private var observingEngineSettingsChanges = false
    @SceneStorage("SYDownload.settings.xhsDirty") private var xhsSettingsDirty = false
    @SceneStorage("SYDownload.settings.douyinDirty") private var douyinSettingsDirty = false

    var body: some View {
        PageContainer(title: "设置") {
            VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
                settingsTabs
                statusBanner
                settingsContent
                saveBarForCurrentTab
            }
        }
        .tint(DesignSystem.accent)
        .preferredColorScheme(preferredAppearance == "浅色" ? .light : preferredAppearance == "深色" ? .dark : nil)
        .animation(reduceMotion ? nil : DesignSystem.motionStandard, value: tab)
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
        .font(DesignSystem.uiFont)
        .frame(height: DesignSystem.controlHeightDefault)
        .accessibilityLabel("设置分类")
    }

    @ViewBuilder
    private var statusBanner: some View {
        if model.settingsLoading {
            HStack(spacing: DesignSystem.spaceS) {
                ProgressView().controlSize(.small)
                Text("正在同步配置")
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: DesignSystem.controlRowMinHeight)
        } else if !model.settingsStatus.isEmpty {
            HStack(spacing: DesignSystem.spaceS) {
                Label(
                    model.settingsStatus,
                    systemImage: model.settingsStatusIsError ? "exclamationmark.triangle" : "checkmark.circle"
                )
                .font(DesignSystem.bodyFont)
                .foregroundStyle(model.settingsStatusIsError ? DesignSystem.destructive : .secondary)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: DesignSystem.spaceM)

                if model.settingsStatusIsError {
                    Button("重新读取") {
                        reloadSettings()
                    }
                    .buttonStyle(.bordered)
                    .font(DesignSystem.uiFont)
                    .frame(height: DesignSystem.controlHeightDefault)
                }
            }
            .frame(minHeight: DesignSystem.controlRowMinHeight)
        }
    }

    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
                switch tab {
                case .general:
                    generalSettings
                case .xhs:
                    xhsSettings
                case .douyin:
                    douyinSettings
                case .advanced:
                    advancedSettings
                }
            }
            .padding(.bottom, DesignSystem.spaceS)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disabled(model.settingsLoading)
        .opacity(model.settingsLoading ? DesignSystem.disabledOpacity : 1)
    }

    @ViewBuilder
    private var generalSettings: some View {
        SettingsSection("保存位置") {
            SettingsRow(showsDivider: false) {
                LabeledContent("下载目录") {
                    HStack(spacing: DesignSystem.spaceS) {
                        TextField("下载目录", text: $model.outputDirectory)
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                            .frame(minWidth: DesignSystem.settingsFieldWidth)
                            .frame(height: DesignSystem.controlHeightDefault)
                        Button("更改") { chooseFolder() }
                            .font(DesignSystem.uiFont)
                            .frame(height: DesignSystem.controlHeightDefault)
                    }
                }
                .font(DesignSystem.bodyFont)
            }

            Text("下载时会同步到小红书的 work_path 与抖音的 root。")
                .font(DesignSystem.metadataFont)
                .foregroundStyle(.secondary)
                .padding(.top, DesignSystem.spaceS)
        }

        SettingsSection("偏好") {
            SettingsRow(showsDivider: false) {
                LabeledContent("应用外观") {
                    Picker("应用外观", selection: $preferredAppearance) {
                        ForEach(["跟随系统", "浅色", "深色"], id: \.self) { value in
                            Text(value).tag(value)
                        }
                    }
                    .labelsHidden()
                    .frame(width: DesignSystem.settingsFieldWidth, height: DesignSystem.controlHeightDefault)
                }
                .font(DesignSystem.bodyFont)
            }
        }

        SettingsSection("更新") {
            SettingsRow {
                LabeledContent("当前版本") {
                    Text(updater.displayVersion)
                        .monospacedDigit()
                        .textSelection(.enabled)
                }
                .font(DesignSystem.bodyFont)
            }

            SettingsRow {
                LabeledContent("更新源") {
                    Picker("更新源", selection: $updater.updateSource) {
                        ForEach(SYDownloadUpdateSource.allCases) { source in
                            Text(source.displayName).tag(source)
                        }
                    }
                    .labelsHidden()
                    .frame(width: DesignSystem.settingsFieldWidth, height: DesignSystem.controlHeightDefault)
                }
                .font(DesignSystem.bodyFont)
            }

            SettingsRow(showsDivider: false) {
                HStack(spacing: DesignSystem.spaceS) {
                    updateStatus
                    Spacer(minLength: DesignSystem.spaceM)
                    Button("检查更新") {
                        updater.checkForUpdates()
                    }
                    .font(DesignSystem.uiFont)
                    .frame(height: DesignSystem.controlHeightDefault)
                    .disabled(updater.isChecking || updater.isUpdating)

                    if updater.updateAvailable {
                        Button("下载安装") {
                            updater.downloadUpdate()
                        }
                        .buttonStyle(.borderedProminent)
                        .font(DesignSystem.uiFont)
                        .frame(height: DesignSystem.controlHeightDefault)
                        .disabled(updater.isUpdating)
                    }
                }
            }

            if updater.isUpdating {
                VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                    ProgressView(value: updater.progressBar.1)
                    Text(updater.progressBar.0)
                        .font(DesignSystem.metadataFont)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, DesignSystem.spaceS)
            }
        }

        SettingsSection("关于") {
            SettingsRow {
                LabeledContent("SYDownload") {
                    Text(updater.displayVersion)
                        .monospacedDigit()
                }
                .font(DesignSystem.bodyFont)
            }

            SettingsRow(showsDivider: false) {
                HStack(spacing: DesignSystem.spaceS) {
                    Button("关于 SYDownload") {
                        NotificationCenter.default.post(name: .syDownloadShowAbout, object: nil)
                    }
                    .font(DesignSystem.uiFont)
                    .frame(height: DesignSystem.controlHeightDefault)

                    Button("查看项目主页") {
                        if let url = URL(string: "https://github.com/iPotatow/SYDownload") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(DesignSystem.uiFont)
                    .frame(height: DesignSystem.controlHeightDefault)
                }
            }
        }
    }

    @ViewBuilder
    private var updateStatus: some View {
        if updater.isChecking {
            HStack(spacing: DesignSystem.spaceS) {
                ProgressView().controlSize(.small)
                Text("正在检查更新…")
            }
            .foregroundStyle(.secondary)
        } else if let error = updater.updateError {
            Label(error, systemImage: "exclamationmark.triangle")
                .foregroundStyle(DesignSystem.destructive)
                .fixedSize(horizontal: false, vertical: true)
        } else if updater.updateAvailable, let release = updater.latestRelease {
            Label("发现新版本 \(release.tagName)", systemImage: "arrow.down.circle.fill")
                .foregroundStyle(DesignSystem.accent)
        } else if let release = updater.latestRelease {
            Label("已是最新版本（\(release.tagName)）", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        } else {
            Text("每天自动检查一次，也可以手动检查。")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var xhsSettings: some View {
        SettingsSection("下载内容") {
            settingsToggleRow("下载图片", isOn: $model.xhsSettings.imageDownload)
            settingsToggleRow("下载视频", isOn: $model.xhsSettings.videoDownload)
            settingsToggleRow("下载动图", isOn: $model.xhsSettings.liveDownload, showsDivider: false)
        }

        SettingsSection("格式") {
            SettingsRow {
                LabeledContent("图片格式") {
                    Picker("图片格式", selection: $model.xhsSettings.imageFormat) {
                        ForEach(["JPEG", "PNG", "WEBP", "HEIC", "AUTO"], id: \.self) { value in
                            Text(value).tag(value)
                        }
                    }
                    .labelsHidden()
                    .frame(width: DesignSystem.settingsFieldWidth, height: DesignSystem.controlHeightDefault)
                }
                .font(DesignSystem.bodyFont)
            }

            SettingsRow {
                LabeledContent("视频偏好") {
                    Picker("视频偏好", selection: $model.xhsSettings.videoPreference) {
                        Text("分辨率优先").tag("resolution")
                        Text("码率优先").tag("bitrate")
                        Text("文件大小优先").tag("size")
                    }
                    .labelsHidden()
                    .frame(width: DesignSystem.settingsFieldWidth, height: DesignSystem.controlHeightDefault)
                }
                .font(DesignSystem.bodyFont)
            }

            SettingsRow(showsDivider: false) {
                LabeledContent("作品信息格式") {
                    Picker("作品信息格式", selection: $model.xhsSettings.noteFormat) {
                        Text("不保存").tag("")
                        Text("TXT").tag("txt")
                        Text("Markdown").tag("md")
                        Text("全部").tag("all")
                    }
                    .labelsHidden()
                    .frame(width: DesignSystem.settingsFieldWidth, height: DesignSystem.controlHeightDefault)
                }
                .font(DesignSystem.bodyFont)
            }
        }

        SettingsSection("文件管理") {
            SettingsRow {
                LabeledContent("文件夹名称") {
                    TextField("文件夹名称", text: $model.xhsSettings.folderName)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: DesignSystem.settingsFieldWidth, height: DesignSystem.controlHeightDefault)
                }
                .font(DesignSystem.bodyFont)
            }

            SettingsRow {
                LabeledContent("文件命名格式") {
                    TextField("发布时间 作者昵称 作品标题", text: $model.xhsSettings.nameFormat)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: DesignSystem.settingsFieldWidth, height: DesignSystem.controlHeightDefault)
                }
                .font(DesignSystem.bodyFont)
            }

            settingsToggleRow("每个作品使用独立文件夹", isOn: $model.xhsSettings.folderMode)
            settingsToggleRow("按作者归档", isOn: $model.xhsSettings.authorArchive)
            settingsToggleRow("记录下载历史", isOn: $model.xhsSettings.downloadRecord)
            settingsToggleRow("将文件修改时间写为作品发布时间", isOn: $model.xhsSettings.writeMtime)
            settingsToggleRow("记录作品数据", isOn: $model.xhsSettings.recordData, showsDivider: false)
        }

        SettingsSection("Cookie") {
            VStack(alignment: .leading, spacing: DesignSystem.spaceS) {
                Text("小红书网页版 Cookie")
                    .font(DesignSystem.bodyFont)
                plainTextEditor(text: $model.xhsSettings.cookie, minHeight: 100)
                    .accessibilityLabel("小红书网页版 Cookie")
            }
        }
    }

    @ViewBuilder
    private var douyinSettings: some View {
        SettingsSection("下载内容") {
            settingsToggleRow("下载音乐", isOn: $model.douyinSettings.music)
            settingsToggleRow("下载动态封面", isOn: $model.douyinSettings.dynamicCover)
            settingsToggleRow("下载静态封面", isOn: $model.douyinSettings.staticCover)
            settingsToggleRow("优先原始画质", isOn: $model.douyinSettings.originalQuality, showsDivider: false)
        }

        SettingsSection("文件管理") {
            SettingsRow {
                LabeledContent("文件夹名称") {
                    TextField("文件夹名称", text: $model.douyinSettings.folderName)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: DesignSystem.settingsFieldWidth, height: DesignSystem.controlHeightDefault)
                }
                .font(DesignSystem.bodyFont)
            }

            SettingsRow {
                LabeledContent("文件命名格式") {
                    TextField("create_time type nickname desc", text: $model.douyinSettings.nameFormat)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: DesignSystem.settingsFieldWidth, height: DesignSystem.controlHeightDefault)
                }
                .font(DesignSystem.bodyFont)
            }

            SettingsRow {
                LabeledContent("描述最大长度") {
                    TextField("64", value: $model.douyinSettings.descLength, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: DesignSystem.settingsFieldWidth, height: DesignSystem.controlHeightDefault)
                }
                .font(DesignSystem.bodyFont)
            }

            SettingsRow {
                LabeledContent("文件名最大长度") {
                    TextField("128", value: $model.douyinSettings.nameLength, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: DesignSystem.settingsFieldWidth, height: DesignSystem.controlHeightDefault)
                }
                .font(DesignSystem.bodyFont)
            }

            SettingsRow {
                LabeledContent("日期格式") {
                    TextField("%Y-%m-%d %H:%M:%S", text: $model.douyinSettings.dateFormat)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: DesignSystem.settingsFieldWidth, height: DesignSystem.controlHeightDefault)
                }
                .font(DesignSystem.bodyFont)
            }

            SettingsRow {
                LabeledContent("文件名分隔符") {
                    TextField("-", text: $model.douyinSettings.split)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: DesignSystem.settingsFieldWidth, height: DesignSystem.controlHeightDefault)
                }
                .font(DesignSystem.bodyFont)
            }

            SettingsRow {
                LabeledContent("数据保存格式") {
                    TextField("留空为不保存", text: $model.douyinSettings.storageFormat)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: DesignSystem.settingsFieldWidth, height: DesignSystem.controlHeightDefault)
                }
                .font(DesignSystem.bodyFont)
            }

            SettingsRow {
                LabeledContent("文件大小限制") {
                    HStack(spacing: DesignSystem.spaceS) {
                        TextField("0", value: $model.douyinSettings.maxSize, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                            .frame(width: DesignSystem.settingsFieldWidth, height: DesignSystem.controlHeightDefault)
                        Text("0 表示不限制")
                            .font(DesignSystem.metadataFont)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(DesignSystem.bodyFont)
            }

            settingsToggleRow("每个作品使用独立文件夹", isOn: $model.douyinSettings.folderMode, showsDivider: false)
        }

        SettingsSection("Cookie") {
            VStack(alignment: .leading, spacing: DesignSystem.spaceS) {
                Text("抖音网页版 Cookie（douyin.com）")
                    .font(DesignSystem.bodyFont)
                plainTextEditor(text: $model.douyinSettings.cookie, minHeight: 92)
                    .accessibilityLabel("抖音网页版 Cookie")
            }
        }
    }

    @ViewBuilder
    private var advancedSettings: some View {
        SettingsSection("原始配置文件") {
            configRow(title: "小红书 settings.json", path: model.xhsSettingsPath, showsDivider: true)
            configRow(title: "抖音 settings.json", path: model.douyinSettingsPath, showsDivider: false)
            Text("界面只修改可见字段；代理、网络超时、重试和浏览器指纹等其他字段会保留在原始 JSON 中。")
                .font(DesignSystem.metadataFont)
                .foregroundStyle(.secondary)
                .padding(.top, DesignSystem.spaceS)
        }

        SettingsSection("恢复默认配置") {
            Text("恢复后会重新读取当前内置版本的上游默认 settings.json。")
                .font(DesignSystem.metadataFont)
                .foregroundStyle(.secondary)

            HStack(spacing: DesignSystem.spaceS) {
                Button("恢复小红书默认设置", role: .destructive) { resetTarget = "xiaohongshu" }
                    .font(DesignSystem.uiFont)
                    .frame(height: DesignSystem.controlHeightDefault)
                Button("恢复抖音默认设置", role: .destructive) { resetTarget = "douyin" }
                    .font(DesignSystem.uiFont)
                    .frame(height: DesignSystem.controlHeightDefault)
            }
            .padding(.top, DesignSystem.spaceS)
        }

        SettingsSection("数据目录") {
            pathRow("应用数据", "~/Library/Application Support/SYDownload/", showsDivider: true)
            pathRow("缓存", "~/Library/Caches/SYDownload/", showsDivider: true)
            pathRow("下载文件", model.outputDirectory, showsDivider: false)
        }
    }

    private func settingsToggleRow(
        _ title: String,
        isOn: Binding<Bool>,
        showsDivider: Bool = true
    ) -> some View {
        SettingsRow(showsDivider: showsDivider) {
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .font(DesignSystem.bodyFont)
        }
    }

    private func configRow(title: String, path: String, showsDivider: Bool) -> some View {
        SettingsRow(showsDivider: showsDivider) {
            HStack(alignment: .center, spacing: DesignSystem.spaceM) {
                VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                    Text(title)
                        .font(DesignSystem.uiFont)
                    Text(path.isEmpty ? "尚未生成" : path)
                        .font(DesignSystem.metadataFont.monospaced())
                        .foregroundStyle(path.isEmpty ? .secondary : .primary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }

                Spacer(minLength: DesignSystem.spaceM)

                Button("打开") { openConfig(path) }
                    .font(DesignSystem.uiFont)
                    .frame(height: DesignSystem.controlHeightCompact)
                    .disabled(path.isEmpty)
                Button("在 Finder 中显示") { revealConfig(path) }
                    .font(DesignSystem.uiFont)
                    .frame(height: DesignSystem.controlHeightCompact)
                    .disabled(path.isEmpty)
            }
            .padding(.vertical, DesignSystem.spaceXS)
        }
    }

    private func pathRow(_ label: String, _ value: String, showsDivider: Bool) -> some View {
        SettingsRow(showsDivider: showsDivider) {
            LabeledContent(label) {
                Text(value)
                    .font(DesignSystem.metadataFont.monospaced())
                    .textSelection(.enabled)
            }
            .font(DesignSystem.bodyFont)
        }
    }

    private func saveBar(
        title: String,
        isDirty: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: DesignSystem.spaceM) {
            Label(
                isDirty ? "有未保存更改" : "当前配置已保存",
                systemImage: isDirty ? "circle.fill" : "checkmark.circle"
            )
            .font(DesignSystem.groupLabelFont)
            .foregroundStyle(isDirty ? DesignSystem.accent : .secondary)

            Spacer(minLength: DesignSystem.spaceM)

            Button(title, action: action)
                .buttonStyle(.borderedProminent)
                .font(DesignSystem.uiFont)
                .frame(height: DesignSystem.controlHeightDefault)
                .disabled(model.settingsLoading || !isDirty)
        }
        .padding(.top, DesignSystem.spaceS)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignSystem.hairline)
                .frame(height: DesignSystem.dividerWidth)
        }
    }

    @ViewBuilder
    private var saveBarForCurrentTab: some View {
        switch tab {
        case .general, .advanced:
            EmptyView()
        case .xhs:
            saveBar(title: "保存小红书设置", isDirty: xhsSettingsDirty, action: saveXHSSettings)
        case .douyin:
            saveBar(title: "保存抖音设置", isDirty: douyinSettingsDirty, action: saveDouyinSettings)
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

    private func reloadSettings() {
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

    private func plainTextEditor(text: Binding<String>, minHeight: CGFloat) -> some View {
        TextEditor(text: text)
            .font(DesignSystem.metadataFont.monospaced())
            .frame(minHeight: minHeight)
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