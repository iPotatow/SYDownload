#if canImport(SwiftUI)
import AppKit
import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case xhs = "小红书"
    case douyin = "抖音"
    case advanced = "高级"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .xhs: return "book.pages"
        case .douyin: return "music.note"
        case .advanced: return "wrench.and.screwdriver"
        }
    }

    var description: String {
        switch self {
        case .xhs: return "小红书内容类型、格式、文件管理和 Cookie"
        case .douyin: return "抖音 / TikTok 内容、文件管理和 Cookie"
        case .advanced: return "FFmpeg、原始配置文件和恢复操作"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @State private var tab: SettingsTab = .xhs
    @State private var resetTarget: String?
    @SceneStorage("SYDownload.engineBaseline.xhs") private var xhsBaseline = ""
    @SceneStorage("SYDownload.engineBaseline.douyin") private var douyinBaseline = ""

    private let fieldWidth: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
            PageHeader(
                title: "引擎配置",
                subtitle: "调整小红书、抖音 / TikTok 下载引擎。应用外观与默认下载目录请使用“设置…”（⌘,）。"
            )

            settingsTabs
            statusBanner
            settingsContent
            saveBar
        }
        .padding(DesignSystem.contentPadding)
        .padding(.bottom, DesignSystem.spaceL)
        .frame(maxWidth: DesignSystem.pageMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .tint(DesignSystem.accent)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: tab)
        .task {
            await model.loadEngineSettings()
            if !model.settingsStatusIsError {
                captureBaselinesIfNeeded()
            }
        }
        .alert("恢复默认配置？", isPresented: Binding(
            get: { resetTarget != nil },
            set: { if !$0 { resetTarget = nil } }
        )) {
            Button("取消", role: .cancel) { resetTarget = nil }
            Button("恢复默认", role: .destructive) {
                resetSelectedEngine()
            }
        } message: {
            Text("这会覆盖当前引擎中已保存的对应设置，并重新读取内置默认值。")
        }
    }

    private var settingsTabs: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    Label(item.rawValue, systemImage: item.systemImage)
                        .font(DesignSystem.uiFont.weight(tab == item ? .semibold : .medium))
                        .foregroundStyle(tab == item ? DesignSystem.accent : Color.secondary)
                        .padding(.horizontal, DesignSystem.spaceM)
                        .frame(height: 36)
                        .frame(maxWidth: .infinity)
                        .background(
                            tab == item ? DesignSystem.accentTint : Color.clear,
                            in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == item ? .isSelected : [])
                .help(item.description)
            }
        }
        .padding(3)
        .background(
            DesignSystem.rowBackground,
            in: RoundedRectangle(cornerRadius: DesignSystem.controlRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.controlRadius, style: .continuous)
                .strokeBorder(DesignSystem.hairline, lineWidth: colorSchemeContrast == .increased ? 2 : 1)
        }
    }

    private var statusBanner: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.spaceS) {
            Text(tab.description)
                .font(DesignSystem.supportingFont)
                .foregroundStyle(.secondary)

            Spacer(minLength: DesignSystem.spaceM)

            if model.settingsLoading {
                ProgressView().controlSize(.small)
                Text("正在同步配置")
                    .foregroundStyle(.secondary)
            } else if currentDirty {
                Label("有未保存更改", systemImage: "circle.fill")
                    .foregroundStyle(DesignSystem.warning)
            } else if !model.settingsStatus.isEmpty {
                Label(
                    model.settingsStatus,
                    systemImage: model.settingsStatusIsError ? "exclamationmark.triangle" : "checkmark.circle"
                )
                .foregroundStyle(model.settingsStatusIsError ? DesignSystem.destructive : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if model.settingsStatusIsError && !model.settingsLoading {
                Button("重新读取", action: reloadSettings)
                    .buttonStyle(.bordered)
            }
        }
        .font(DesignSystem.supportingFont)
    }

    private var settingsContent: some View {
        Form {
            switch tab {
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
    private var xhsSettings: some View {
        Section("下载内容") {
            Toggle("下载图片", isOn: $model.xhsSettings.imageDownload)
            Toggle("下载视频", isOn: $model.xhsSettings.videoDownload)
            Toggle("下载动图", isOn: $model.xhsSettings.liveDownload)
        }

        Section("格式") {
            LabeledContent("图片格式") {
                Picker("图片格式", selection: $model.xhsSettings.imageFormat) {
                    ForEach(["JPEG", "PNG", "WEBP", "HEIC", "AUTO"], id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(width: fieldWidth)
            }
            LabeledContent("视频偏好") {
                Picker("视频偏好", selection: $model.xhsSettings.videoPreference) {
                    Text("分辨率优先").tag("resolution")
                    Text("码率优先").tag("bitrate")
                    Text("文件大小优先").tag("size")
                }
                .labelsHidden()
                .frame(width: fieldWidth)
            }
            LabeledContent("作品信息格式") {
                Picker("作品信息格式", selection: $model.xhsSettings.noteFormat) {
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
                TextField("文件夹名称", text: $model.xhsSettings.folderName)
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
            Toggle("每个作品使用独立文件夹", isOn: $model.xhsSettings.folderMode).toggleStyle(.switch)
            Toggle("按作者归档", isOn: $model.xhsSettings.authorArchive).toggleStyle(.switch)
            Toggle("记录下载历史", isOn: $model.xhsSettings.downloadRecord).toggleStyle(.switch)
            Toggle("将文件修改时间写为作品发布时间", isOn: $model.xhsSettings.writeMtime).toggleStyle(.switch)
            Toggle("记录作品数据", isOn: $model.xhsSettings.recordData).toggleStyle(.switch)
        }

        Section("Cookie") {
            TextEditor(text: $model.xhsSettings.cookie)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 100)
                .accessibilityLabel("小红书网页版 Cookie")
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
            engineTextField("文件夹名称", text: $model.douyinSettings.folderName)
            engineTextField("文件命名格式", text: $model.douyinSettings.nameFormat)
            engineNumberField("描述最大长度", value: $model.douyinSettings.descLength)
            engineNumberField("文件名最大长度", value: $model.douyinSettings.nameLength)
            engineTextField("日期格式", text: $model.douyinSettings.dateFormat)
            engineTextField("文件名分隔符", text: $model.douyinSettings.split)
            engineTextField("数据保存格式", text: $model.douyinSettings.storageFormat)
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
            Toggle("每个作品使用独立文件夹", isOn: $model.douyinSettings.folderMode).toggleStyle(.switch)
        }

        Section("Cookie") {
            VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
                VStack(alignment: .leading, spacing: DesignSystem.spaceS) {
                    Text("国内链接 Cookie（douyin.com）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $model.douyinSettings.cookie)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 90)
                        .accessibilityLabel("国内链接 Cookie")
                }
                VStack(alignment: .leading, spacing: DesignSystem.spaceS) {
                    Text("国际链接 Cookie（tiktok.com）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $model.douyinSettings.cookieTikTok)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 90)
                        .accessibilityLabel("国际链接 Cookie")
                }
            }
        }
    }

    @ViewBuilder
    private var advancedSettings: some View {
        Section("抖音高级功能") {
            engineTextField("FFmpeg 路径", text: $model.douyinSettings.ffmpeg)
            engineTextField("直播画质", text: $model.douyinSettings.liveQualities)
        }

        Section("原始配置文件") {
            configRow(title: "小红书 settings.json", path: model.xhsSettingsPath)
            configRow(title: "抖音 settings.json", path: model.douyinSettingsPath)
            Text("App 只修改界面中可见的字段；未展示字段会原样保留在原始 JSON 中。")
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
            pathRow("默认下载目录", model.outputDirectory)
        }
    }

    private var saveBar: some View {
        HStack(spacing: DesignSystem.spaceM) {
            Label(
                currentDirty ? "有未保存更改" : "当前配置已保存",
                systemImage: currentDirty ? "circle.fill" : "checkmark.circle"
            )
            .font(.caption)
            .foregroundStyle(currentDirty ? DesignSystem.warning : Color.secondary)

            Spacer(minLength: DesignSystem.spaceM)

            Button(saveButtonTitle, action: saveCurrentTab)
                .buttonStyle(.borderedProminent)
                .disabled(model.settingsLoading || !currentDirty)
        }
        .padding(.vertical, DesignSystem.spaceS)
    }

    private var saveButtonTitle: String {
        switch tab {
        case .xhs: return "保存小红书设置"
        case .douyin: return "保存抖音设置"
        case .advanced: return "保存高级设置"
        }
    }

    private var currentDirty: Bool {
        switch tab {
        case .xhs: return !xhsBaseline.isEmpty && xhsBaseline != xhsSignature
        case .douyin, .advanced: return !douyinBaseline.isEmpty && douyinBaseline != douyinSignature
        }
    }

    private var xhsSignature: String {
        [
            model.outputDirectory,
            String(model.xhsSettings.imageDownload), String(model.xhsSettings.videoDownload),
            String(model.xhsSettings.liveDownload), model.xhsSettings.imageFormat,
            model.xhsSettings.videoPreference, model.xhsSettings.noteFormat,
            model.xhsSettings.folderName, model.xhsSettings.nameFormat,
            String(model.xhsSettings.folderMode), String(model.xhsSettings.authorArchive),
            String(model.xhsSettings.downloadRecord), String(model.xhsSettings.writeMtime),
            String(model.xhsSettings.recordData), model.xhsSettings.cookie
        ].joined(separator: "\u{1F}")
    }

    private var douyinSignature: String {
        [
            model.outputDirectory,
            String(model.douyinSettings.music), String(model.douyinSettings.dynamicCover),
            String(model.douyinSettings.staticCover), String(model.douyinSettings.originalQuality),
            model.douyinSettings.folderName, String(model.douyinSettings.folderMode),
            model.douyinSettings.nameFormat, String(model.douyinSettings.descLength),
            String(model.douyinSettings.nameLength), model.douyinSettings.dateFormat,
            model.douyinSettings.split, model.douyinSettings.storageFormat,
            String(model.douyinSettings.maxSize), model.douyinSettings.cookie,
            model.douyinSettings.cookieTikTok, model.douyinSettings.ffmpeg,
            model.douyinSettings.liveQualities
        ].joined(separator: "\u{1F}")
    }

    @ViewBuilder
    private func engineTextField(_ label: String, text: Binding<String>) -> some View {
        LabeledContent(label) {
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .frame(width: fieldWidth)
        }
    }

    @ViewBuilder
    private func engineNumberField(_ label: String, value: Binding<Int>) -> some View {
        LabeledContent(label) {
            TextField(label, value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .frame(width: fieldWidth)
        }
    }

    private func captureBaselinesIfNeeded() {
        if xhsBaseline.isEmpty { xhsBaseline = xhsSignature }
        if douyinBaseline.isEmpty { douyinBaseline = douyinSignature }
    }

    private func captureAllBaselines() {
        xhsBaseline = xhsSignature
        douyinBaseline = douyinSignature
    }

    private func saveCurrentTab() {
        Task {
            switch tab {
            case .xhs:
                await model.saveXHSSettings()
                if !model.settingsStatusIsError { xhsBaseline = xhsSignature }
            case .douyin, .advanced:
                await model.saveDouyinSettings()
                if !model.settingsStatusIsError { douyinBaseline = douyinSignature }
            }
        }
    }

    private func reloadSettings() {
        Task {
            await model.loadEngineSettings(force: true)
            if !model.settingsStatusIsError { captureAllBaselines() }
        }
    }

    private func resetSelectedEngine() {
        guard let target = resetTarget else { return }
        resetTarget = nil
        Task {
            await model.resetEngineSettings(target)
            if !model.settingsStatusIsError { captureAllBaselines() }
        }
    }

    private func configRow(title: String, path: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 13, weight: .medium))
            Text(path.isEmpty ? "尚未生成" : path)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(path.isEmpty ? .secondary : .primary)
                .textSelection(.enabled)
            HStack(spacing: DesignSystem.spaceS) {
                Button("打开") { openConfig(path) }.disabled(path.isEmpty)
                Button("在 Finder 中显示") { revealConfig(path) }.disabled(path.isEmpty)
            }
        }
    }

    private func pathRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
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
