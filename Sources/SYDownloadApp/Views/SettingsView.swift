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

private enum SettingsFocusField: Hashable {
    case downloadDirectory
    case xhsCookie
    case douyinCookie
}

private struct SettingsChoice<Value: Hashable>: Identifiable {
    let id: String
    let value: Value
    let title: String

    init(_ id: String, value: Value, title: String) {
        self.id = id
        self.value = value
        self.title = title
    }
}

private struct SettingsPopupSelector<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let choices: [SettingsChoice<Value>]

    private var selectedTitle: String {
        choices.first(where: { $0.value == selection })?.title ?? "未选择"
    }

    var body: some View {
        Menu {
            ForEach(choices) { choice in
                Button {
                    selection = choice.value
                } label: {
                    if choice.value == selection {
                        Label(choice.title, remixSystemImage: "checkmark")
                    } else {
                        Text(choice.title)
                    }
                }
            }
        } label: {
            HStack(spacing: CoreSpacing.s) {
                Text(selectedTitle)
                    .coreTypography(CoreTypography.body)
                    .foregroundStyle(CoreColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: CoreSpacing.s)
                RemixIcon(systemName: "chevron.up.chevron.down", size: 12)
                    .foregroundStyle(CoreColor.textSecondary)
            }
            .padding(.horizontal, CoreMetrics.controlHorizontalPadding)
            .frame(width: SYDownloadLayout.settingsFieldWidth, height: CoreMetrics.controlHeightDefault)
            .background(
                CoreColor.controlBackground,
                in: RoundedRectangle(cornerRadius: CoreRadius.row, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CoreRadius.row, style: .continuous)
                    .strokeBorder(CoreColor.border, lineWidth: CoreMetrics.borderWidth)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: SYDownloadLayout.settingsFieldWidth, height: CoreMetrics.controlHeightDefault, alignment: .trailing)
        .accessibilityLabel(title)
        .accessibilityValue(selectedTitle)
    }
}

private struct NameFormatOption: Identifiable, Hashable {
    let rawValue: String
    let title: String
    var id: String { rawValue }
}

private struct NameFormatSelector: View {
    let title: String
    @Binding var value: String
    let options: [NameFormatOption]
    let fallback: [String]
    @State private var isPresented = false

    private var validValues: Set<String> { Set(options.map(\.rawValue)) }

    private var selectedTokens: [String] {
        let parsed = value.split(whereSeparator: \.isWhitespace).map(String.init)
        var seen = Set<String>()
        let valid = parsed.filter { validValues.contains($0) && seen.insert($0).inserted }
        return valid.isEmpty ? fallback : valid
    }

    private var selectedSummary: String {
        let labels = selectedTokens.compactMap { token in
            options.first(where: { $0.rawValue == token })?.title
        }
        return labels.joined(separator: " · ")
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: CoreSpacing.s) {
                Text(selectedSummary)
                    .coreTypography(CoreTypography.body)
                    .foregroundStyle(CoreColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: CoreSpacing.s)
                RemixIcon(systemName: "chevron.down", size: 12)
                    .foregroundStyle(CoreColor.textSecondary)
            }
            .padding(.horizontal, CoreMetrics.controlHorizontalPadding)
            .frame(width: SYDownloadLayout.settingsFieldWidth, height: CoreMetrics.controlHeightDefault)
            .background(
                CoreColor.controlBackground,
                in: RoundedRectangle(cornerRadius: CoreRadius.row, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CoreRadius.row, style: .continuous)
                    .strokeBorder(CoreColor.border, lineWidth: CoreMetrics.borderWidth)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: SYDownloadLayout.settingsFieldWidth, height: CoreMetrics.controlHeightDefault, alignment: .trailing)
        .popover(isPresented: $isPresented) {
            nameFormatPopover
        }
        .accessibilityLabel(title)
        .accessibilityValue(selectedSummary)
    }

    private var nameFormatPopover: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.m) {
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text(title)
                    .coreTypography(CoreTypography.sectionTitle)
                    .foregroundStyle(CoreColor.textPrimary)
                Text("至少保留一个字段；已选字段可用右侧箭头调整文件名顺序。")
                    .coreTypography(CoreTypography.caption)
                    .foregroundStyle(CoreColor.textSecondary)
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(options) { option in
                        optionRow(option)
                    }
                }
            }
            .frame(maxHeight: 360)
        }
        .padding(CoreSpacing.l)
        .frame(width: 380)
    }

    private func optionRow(_ option: NameFormatOption) -> some View {
        let tokens = selectedTokens
        let selected = tokens.contains(option.rawValue)
        let selectedIndex = tokens.firstIndex(of: option.rawValue)

        return HStack(spacing: CoreSpacing.s) {
            Button {
                toggle(option.rawValue)
            } label: {
                HStack(spacing: CoreSpacing.s) {
                    RemixIcon(systemName: selected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(selected ? CoreColor.accent : CoreColor.textSecondary)
                    Text(option.title)
                        .coreTypography(CoreTypography.body)
                        .foregroundStyle(CoreColor.textPrimary)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(selected && tokens.count == 1)

            if let selectedIndex {
                Button {
                    move(option.rawValue, offset: -1)
                } label: {
                    RemixIcon(systemName: "chevron.up")
                }
                .buttonStyle(.plain)
                .foregroundStyle(CoreColor.textSecondary)
                .disabled(selectedIndex == 0)
                .help("向前移动")

                Button {
                    move(option.rawValue, offset: 1)
                } label: {
                    RemixIcon(systemName: "chevron.down")
                }
                .buttonStyle(.plain)
                .foregroundStyle(CoreColor.textSecondary)
                .disabled(selectedIndex == tokens.count - 1)
                .help("向后移动")
            } else {
                Color.clear.frame(width: 28, height: 20)
                Color.clear.frame(width: 28, height: 20)
            }
        }
        .frame(minHeight: CoreMetrics.settingsRowMinHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CoreColor.divider)
                .frame(height: CoreMetrics.dividerWidth)
        }
    }

    private func toggle(_ token: String) {
        var tokens = selectedTokens
        if let index = tokens.firstIndex(of: token) {
            guard tokens.count > 1 else { return }
            tokens.remove(at: index)
        } else {
            tokens.append(token)
        }
        value = tokens.joined(separator: " ")
    }

    private func move(_ token: String, offset: Int) {
        var tokens = selectedTokens
        guard let index = tokens.firstIndex(of: token) else { return }
        let target = index + offset
        guard tokens.indices.contains(target) else { return }
        tokens.swapAt(index, target)
        value = tokens.joined(separator: " ")
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var updater: SYDownloadUpdater
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var tab: SettingsTab = .general
    @AppStorage("preferredAppearance") private var preferredAppearance = "跟随系统"
    @AppStorage("browserCookieSource") private var browserCookieSource = "Chrome"
    @State private var resetTarget: String?
    @State private var observingEngineSettingsChanges = false
    @State private var revealsXHSCookie = false
    @State private var revealsDouyinCookie = false
    @FocusState private var focusedField: SettingsFocusField?

    private let xhsNameOptions = [
        NameFormatOption(rawValue: "收藏数量", title: "收藏数量"),
        NameFormatOption(rawValue: "评论数量", title: "评论数量"),
        NameFormatOption(rawValue: "分享数量", title: "分享数量"),
        NameFormatOption(rawValue: "点赞数量", title: "点赞数量"),
        NameFormatOption(rawValue: "作品标签", title: "作品标签"),
        NameFormatOption(rawValue: "作品ID", title: "作品 ID"),
        NameFormatOption(rawValue: "作品标题", title: "作品标题"),
        NameFormatOption(rawValue: "作品描述", title: "作品描述"),
        NameFormatOption(rawValue: "作品类型", title: "作品类型"),
        NameFormatOption(rawValue: "发布时间", title: "发布时间"),
        NameFormatOption(rawValue: "最后更新时间", title: "最后更新时间"),
        NameFormatOption(rawValue: "作者昵称", title: "作者昵称"),
        NameFormatOption(rawValue: "作者ID", title: "作者 ID"),
    ]

    private let browserCookieChoices = [
        SettingsChoice("chrome", value: "Chrome", title: "Chrome"),
        SettingsChoice("safari", value: "Safari", title: "Safari"),
        SettingsChoice("arc", value: "Arc", title: "Arc"),
        SettingsChoice("edge", value: "Edge", title: "Edge"),
        SettingsChoice("brave", value: "Brave", title: "Brave"),
        SettingsChoice("chromium", value: "Chromium", title: "Chromium"),
        SettingsChoice("firefox", value: "Firefox", title: "Firefox"),
        SettingsChoice("librewolf", value: "LibreWolf", title: "LibreWolf"),
        SettingsChoice("opera", value: "Opera", title: "Opera"),
        SettingsChoice("operagx", value: "OperaGX", title: "Opera GX"),
        SettingsChoice("vivaldi", value: "Vivaldi", title: "Vivaldi"),
    ]

    private let douyinNameOptions = [
        NameFormatOption(rawValue: "id", title: "作品 ID"),
        NameFormatOption(rawValue: "desc", title: "作品描述"),
        NameFormatOption(rawValue: "create_time", title: "发布时间"),
        NameFormatOption(rawValue: "nickname", title: "作者昵称"),
        NameFormatOption(rawValue: "uid", title: "作者 ID"),
        NameFormatOption(rawValue: "mark", title: "作者备注"),
        NameFormatOption(rawValue: "type", title: "作品类型"),
    ]

    var body: some View {
        CorePageContainer(title: "设置", maxWidth: SYDownloadLayout.contentMaxWidth) {
            VStack(alignment: .leading, spacing: CoreSpacing.l) {
                settingsTabs
                if showsEngineStatus {
                    statusBanner
                }
                settingsContent
                saveBarForCurrentTab
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .tint(CoreColor.accent)
        .preferredColorScheme(preferredAppearance == "浅色" ? .light : preferredAppearance == "深色" ? .dark : nil)
        .animation(reduceMotion ? nil : CoreMotion.standard, value: tab)
        .task {
            let isInitialLoad = !model.hasLoadedEngineSettings
            observingEngineSettingsChanges = false
            await model.loadEngineSettings()
            if isInitialLoad && model.hasLoadedEngineSettings {
                model.xhsSettingsDirty = false
                model.douyinSettingsDirty = false
            }
            observingEngineSettingsChanges = true
            handleSettingsDestination()
        }
        .onReceive(model.$xhsSettings.dropFirst()) { _ in
            guard observingEngineSettingsChanges, !model.settingsLoading else { return }
            model.xhsSettingsDirty = true
        }
        .onReceive(model.$douyinSettings.dropFirst()) { _ in
            guard observingEngineSettingsChanges, !model.settingsLoading else { return }
            model.douyinSettingsDirty = true
        }
        .onChange(of: model.settingsDestination) { _, _ in
            handleSettingsDestination()
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
                            model.xhsSettingsDirty = false
                        } else if target == "douyin" {
                            model.douyinSettingsDirty = false
                        }
                    }
                }
            }
        } message: {
            Text("这会覆盖当前引擎中已保存的对应设置，并重新读取内置默认值。")
        }
    }

    private var showsEngineStatus: Bool {
        guard tab == .xhs || tab == .douyin || tab == .advanced else { return false }
        guard let scope = model.settingsStatusEngine else { return true }
        switch tab {
        case .xhs: return scope == "xiaohongshu"
        case .douyin: return scope == "douyin"
        case .advanced: return false
        default: return false
        }
    }

    private var settingsTabs: some View {
        CenteredControl(width: RefinementLayout.settingsTabsWidth) {
            Picker("设置分类", selection: $tab) {
                ForEach(SettingsTab.allCases) { item in
                    Label(settingsTabTitle(item), remixSystemImage: item.systemImage)
                        .tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .font(CoreTypography.controlFont)
            .frame(height: CoreMetrics.controlHeightDefault)
            .accessibilityLabel("设置分类")
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if model.settingsLoading {
            HStack(spacing: CoreSpacing.s) {
                ProgressView().controlSize(.small)
                Text("正在同步配置")
                    .coreTypography(CoreTypography.body)
                    .foregroundStyle(CoreColor.textSecondary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: CoreMetrics.controlRowMinHeight)
        } else if !model.settingsStatus.isEmpty {
            HStack(spacing: CoreSpacing.s) {
                Label(
                    model.settingsStatus, remixSystemImage: model.settingsStatusIsError ? "exclamationmark.triangle" : "checkmark.circle"
                )
                .coreTypography(CoreTypography.body)
                .foregroundStyle(model.settingsStatusIsError ? CoreColor.danger : CoreColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: CoreSpacing.m)

                if model.settingsStatusIsError {
                    Button("重新读取") { reloadSettings() }
                        .buttonStyle(.bordered)
                        .font(CoreTypography.controlFont)
                        .frame(height: CoreMetrics.controlHeightDefault)
                }
            }
            .frame(maxWidth: .infinity, minHeight: CoreMetrics.controlRowMinHeight)
        }
    }

    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CoreSpacing.l) {
                switch tab {
                case .general: generalSettings
                case .xhs: xhsSettings
                case .douyin: douyinSettings
                case .advanced: advancedSettings
                }
            }
            .padding(.bottom, CoreSpacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disabled(model.settingsLoading && showsEngineStatus)
        .opacity(model.settingsLoading && showsEngineStatus ? CoreState.disabledOpacity : 1)
    }

    @ViewBuilder
    private var generalSettings: some View {
        CoreSettingsSection("保存位置") {
            SettingsControlRow("下载目录", showsDivider: false) {
                HStack(spacing: CoreSpacing.s) {
                    TextField("下载目录", text: $model.outputDirectory)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .focused($focusedField, equals: .downloadDirectory)
                        .frame(width: RefinementLayout.settingsPathFieldWidth)
                        .frame(height: CoreMetrics.controlHeightDefault)
                        .disabled(model.activeTaskCount > 0)
                    Button("更改") { chooseFolder() }
                        .font(CoreTypography.controlFont)
                        .frame(height: CoreMetrics.controlHeightDefault)
                        .disabled(model.activeTaskCount > 0)
                }
            }

            if let issue = model.outputDirectoryIssue {
                Text(issue)
                    .coreTypography(CoreTypography.caption)
                    .foregroundStyle(CoreColor.danger)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, CoreSpacing.s)
            } else {
                Text(
                    model.activeTaskCount > 0
                        ? "有任务运行时暂不允许更改下载目录。"
                        : "小红书与抖音都会直接保存到这个目录，不再额外创建 Download 文件夹。"
                )
                    .coreTypography(CoreTypography.caption)
                    .foregroundStyle(CoreColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, CoreSpacing.s)
            }
        }

        CoreSettingsSection("重复文件") {
            SettingsControlRow("同名文件处理", showsDivider: false) {
                Picker("同名文件处理", selection: $model.overwriteExistingFiles) {
                    Text("保留并跳过").tag(false)
                    Text("覆盖重新下载").tag(true)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: SYDownloadLayout.settingsFieldWidth)
                .accessibilityLabel("同名文件处理")
            }

            Text("这个选项独立于小红书的“引擎下载记录”。关闭下载记录后，如果磁盘上已有同名文件，上游仍会跳过；选择“覆盖重新下载”才会绕过记录和同名文件检查。")
                .coreTypography(CoreTypography.caption)
                .foregroundStyle(CoreColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, CoreSpacing.s)
        }

        CoreSettingsSection("偏好") {
            SettingsControlRow("应用外观", showsDivider: false) {
                SettingsPopupSelector(
                    title: "应用外观",
                    selection: $preferredAppearance,
                    choices: [
                        SettingsChoice("system", value: "跟随系统", title: "跟随系统"),
                        SettingsChoice("light", value: "浅色", title: "浅色"),
                        SettingsChoice("dark", value: "深色", title: "深色"),
                    ]
                )
            }
        }
    }

    @ViewBuilder
    private var updateSettings: some View {
        CoreSettingsSection("更新") {
            SettingsControlRow("当前版本") {
                Text(updater.displayVersion)
                    .coreTypography(CoreTypography.body)
                    .monospacedDigit()
                    .textSelection(.enabled)
            }

            SettingsControlRow("更新源") {
                SettingsPopupSelector(
                    title: "更新源",
                    selection: $updater.updateSource,
                    choices: SYDownloadUpdateSource.allCases.map {
                        SettingsChoice($0.rawValue, value: $0, title: $0.displayName)
                    }
                )
            }

            CoreSettingsRow(showsDivider: false) {
                HStack(spacing: CoreSpacing.s) {
                    updateStatus
                    Spacer(minLength: CoreSpacing.m)
                    Button("检查更新") {
                        updater.checkForUpdates()
                    }
                    .font(CoreTypography.controlFont)
                    .frame(height: CoreMetrics.controlHeightDefault)
                    .disabled(updater.isChecking || updater.isUpdating)

                    if updater.updateAvailable {
                        Button("更新并重启") {
                            updater.downloadUpdate()
                        }
                        .buttonStyle(.borderedProminent)
                        .font(CoreTypography.controlFont)
                        .frame(height: CoreMetrics.controlHeightDefault)
                        .disabled(updater.isUpdating)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            if updater.isUpdating {
                VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                    ProgressView(value: updater.progressBar.1)
                    Text(updater.progressBar.0)
                        .coreTypography(CoreTypography.caption)
                        .foregroundStyle(CoreColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, CoreSpacing.s)
            }
        }
    }

    @ViewBuilder
    private var updateStatus: some View {
        if updater.isChecking {
            HStack(spacing: CoreSpacing.s) {
                ProgressView().controlSize(.small)
                Text("正在检查更新…")
            }
            .foregroundStyle(CoreColor.textSecondary)
        } else if let error = updater.updateError {
            Label(error, remixSystemImage: "exclamationmark.triangle")
                .foregroundStyle(CoreColor.danger)
                .fixedSize(horizontal: false, vertical: true)
        } else if updater.updateAvailable, let release = updater.latestRelease {
            Label("发现新版本 \(release.tagName)", remixSystemImage: "arrow.down.circle.fill")
                .foregroundStyle(CoreColor.accent)
        } else if let release = updater.latestRelease {
            Label("已是最新版本（\(release.tagName)）", remixSystemImage: "checkmark.circle")
                .foregroundStyle(CoreColor.textSecondary)
        } else {
            Text("每天自动检查一次，也可以手动检查。")
                .foregroundStyle(CoreColor.textSecondary)
        }
    }

    @ViewBuilder
    private var aboutSettings: some View {
        CoreSettingsSection("关于 SYDownload") {
            CoreSettingsRow {
                HStack(spacing: CoreSpacing.l) {
                    AppMark(size: 48)
                    VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                        Text("SYDownload")
                            .coreTypography(CoreTypography.sectionTitle)
                            .foregroundStyle(CoreColor.textPrimary)
                        Text("小红书与抖音下载工具 · \(updater.displayVersion)")
                            .coreTypography(CoreTypography.body)
                            .foregroundStyle(CoreColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, CoreSpacing.s)
            }

            CoreSettingsRow {
                Text("自动识别分享链接并调用内置下载引擎；媒体文件直接写入你选择的下载目录。")
                    .coreTypography(CoreTypography.body)
                    .foregroundStyle(CoreColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            CoreSettingsRow(showsDivider: false) {
                HStack(spacing: CoreSpacing.s) {
                    Spacer(minLength: 0)
                    Button("问题反馈") {
                        open("https://github.com/iPotatow/SYDownload/issues")
                    }
                    .font(CoreTypography.controlFont)
                    .frame(height: CoreMetrics.controlHeightDefault)
                    Button("使用文档") {
                        open("https://github.com/iPotatow/SYDownload#readme")
                    }
                    .font(CoreTypography.controlFont)
                    .frame(height: CoreMetrics.controlHeightDefault)
                    Button("打开 GitHub 仓库") {
                        open("https://github.com/iPotatow/SYDownload")
                    }
                    .buttonStyle(.borderedProminent)
                    .font(CoreTypography.controlFont)
                    .frame(height: CoreMetrics.controlHeightDefault)
                }
                .frame(maxWidth: .infinity)
            }
        }

        CoreSettingsSection("开源组件") {
            SettingsControlRow("下载引擎") {
                Text("XHS-Downloader · TikTokDownloader")
                    .coreTypography(CoreTypography.body)
                    .foregroundStyle(CoreColor.textSecondary)
            }
            SettingsControlRow("许可证", showsDivider: false) {
                Text("GPL-3.0")
                    .coreTypography(CoreTypography.body)
                    .foregroundStyle(CoreColor.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var xhsSettings: some View {
        CoreSettingsSection("下载内容") {
            settingsToggleRow("下载图片", isOn: $model.xhsSettings.imageDownload)
            settingsToggleRow("下载视频", isOn: $model.xhsSettings.videoDownload)
            settingsToggleRow("下载动图", isOn: $model.xhsSettings.liveDownload, showsDivider: false)
        }

        CoreSettingsSection("格式") {
            SettingsControlRow("图片格式") {
                SettingsPopupSelector(
                    title: "图片格式",
                    selection: $model.xhsSettings.imageFormat,
                    choices: ["JPEG", "PNG", "WEBP", "HEIC", "AUTO"].map {
                        SettingsChoice($0, value: $0, title: $0)
                    }
                )
            }

            SettingsControlRow("视频偏好") {
                SettingsPopupSelector(
                    title: "视频偏好",
                    selection: $model.xhsSettings.videoPreference,
                    choices: [
                        SettingsChoice("resolution", value: "resolution", title: "分辨率优先"),
                        SettingsChoice("bitrate", value: "bitrate", title: "码率优先"),
                        SettingsChoice("size", value: "size", title: "文件大小优先"),
                    ]
                )
            }

            SettingsControlRow("作品信息格式", showsDivider: false) {
                SettingsPopupSelector(
                    title: "作品信息格式",
                    selection: $model.xhsSettings.noteFormat,
                    choices: [
                        SettingsChoice("none", value: "", title: "不保存"),
                        SettingsChoice("txt", value: "txt", title: "TXT"),
                        SettingsChoice("md", value: "md", title: "Markdown"),
                        SettingsChoice("all", value: "all", title: "全部"),
                    ]
                )
            }
        }

        CoreSettingsSection("文件管理") {
            SettingsControlRow("文件命名格式") {
                NameFormatSelector(
                    title: "小红书文件命名格式",
                    value: $model.xhsSettings.nameFormat,
                    options: xhsNameOptions,
                    fallback: ["发布时间", "作者昵称", "作品标题"]
                )
            }

            settingsToggleRow("每个作品使用独立文件夹", isOn: $model.xhsSettings.folderMode)
            settingsToggleRow("按作者归档", isOn: $model.xhsSettings.authorArchive)
            settingsToggleRow("记录小红书引擎下载记录", isOn: $model.xhsSettings.downloadRecord)
            Text("仅控制上游按作品 ID 的下载记录去重，不控制磁盘同名文件检查；重复文件策略在“通用”中设置。")
                .coreTypography(CoreTypography.caption)
                .foregroundStyle(CoreColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, CoreSpacing.xs)
            settingsToggleRow("将文件修改时间写为作品发布时间", isOn: $model.xhsSettings.writeMtime)
            settingsToggleRow("记录作品数据", isOn: $model.xhsSettings.recordData, showsDivider: false)
        }

        CoreSettingsSection("Cookie") {
            browserCookieRow(engine: "xiaohongshu")

            VStack(alignment: .leading, spacing: CoreSpacing.s) {
                Text("小红书网页版 Cookie")
                    .coreTypography(CoreTypography.body)
                cookieEditor(
                    text: $model.xhsSettings.cookie,
                    minHeight: 100,
                    field: .xhsCookie,
                    isRevealed: $revealsXHSCookie
                )
                    .accessibilityLabel("小红书网页版 Cookie")
                browserCookieHelp
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var douyinSettings: some View {
        CoreSettingsSection("下载内容") {
            settingsToggleRow("下载音乐", isOn: $model.douyinSettings.music)
            settingsToggleRow("下载动态封面", isOn: $model.douyinSettings.dynamicCover)
            settingsToggleRow("下载静态封面", isOn: $model.douyinSettings.staticCover)
            settingsToggleRow("优先原始画质", isOn: $model.douyinSettings.originalQuality, showsDivider: false)
        }

        CoreSettingsSection("文件管理") {
            SettingsControlRow("文件命名格式") {
                NameFormatSelector(
                    title: "抖音文件命名格式",
                    value: $model.douyinSettings.nameFormat,
                    options: douyinNameOptions,
                    fallback: ["create_time", "type", "nickname", "desc"]
                )
            }

            SettingsControlRow("描述最大长度") {
                TextField("64", value: $model.douyinSettings.descLength, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: SYDownloadLayout.settingsFieldWidth, height: CoreMetrics.controlHeightDefault)
            }

            SettingsControlRow("文件名最大长度") {
                TextField("128", value: $model.douyinSettings.nameLength, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: SYDownloadLayout.settingsFieldWidth, height: CoreMetrics.controlHeightDefault)
            }

            SettingsControlRow("日期格式") {
                TextField("%Y-%m-%d %H:%M:%S", text: $model.douyinSettings.dateFormat)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: SYDownloadLayout.settingsFieldWidth, height: CoreMetrics.controlHeightDefault)
            }

            SettingsControlRow("文件名分隔符") {
                TextField("-", text: $model.douyinSettings.split)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: SYDownloadLayout.settingsFieldWidth, height: CoreMetrics.controlHeightDefault)
            }

            SettingsControlRow("数据保存格式") {
                TextField("留空为不保存", text: $model.douyinSettings.storageFormat)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: SYDownloadLayout.settingsFieldWidth, height: CoreMetrics.controlHeightDefault)
            }

            SettingsControlRow("文件大小限制") {
                HStack(spacing: CoreSpacing.s) {
                    TextField("0", value: $model.douyinSettings.maxSize, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: SYDownloadLayout.settingsFieldWidth, height: CoreMetrics.controlHeightDefault)
                    Text("0 表示不限制")
                        .coreTypography(CoreTypography.caption)
                        .foregroundStyle(CoreColor.textSecondary)
                }
            }

            settingsToggleRow("每个作品使用独立文件夹", isOn: $model.douyinSettings.folderMode, showsDivider: false)

            if let validation = model.douyinSettingsValidationMessage {
                Text(validation)
                    .coreTypography(CoreTypography.caption)
                    .foregroundStyle(CoreColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, CoreSpacing.s)
            }
        }

        CoreSettingsSection("Cookie") {
            browserCookieRow(engine: "douyin")

            VStack(alignment: .leading, spacing: CoreSpacing.s) {
                Text("抖音网页版 Cookie（douyin.com）")
                    .coreTypography(CoreTypography.body)
                cookieEditor(
                    text: $model.douyinSettings.cookie,
                    minHeight: 92,
                    field: .douyinCookie,
                    isRevealed: $revealsDouyinCookie
                )
                    .accessibilityLabel("抖音网页版 Cookie")
                browserCookieHelp
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var advancedSettings: some View {
        CoreSettingsSection("原始配置文件") {
            configRow(title: "小红书 settings.json", path: model.xhsSettingsPath, showsDivider: true)
            configRow(title: "抖音 settings.json", path: model.douyinSettingsPath, showsDivider: false)
            Text("界面只修改可见字段；代理、网络超时、重试和浏览器指纹等其他字段会保留在原始 JSON 中。")
                .coreTypography(CoreTypography.caption)
                .foregroundStyle(CoreColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, CoreSpacing.s)
        }

        CoreSettingsSection("恢复默认配置") {
            Text("恢复后会重新读取当前内置版本的上游默认 settings.json。")
                .coreTypography(CoreTypography.caption)
                .foregroundStyle(CoreColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: CoreSpacing.s) {
                Spacer(minLength: 0)
                Button("恢复小红书默认设置", role: .destructive) { resetTarget = "xiaohongshu" }
                    .font(CoreTypography.controlFont)
                    .frame(height: CoreMetrics.controlHeightDefault)
                Button("恢复抖音默认设置", role: .destructive) { resetTarget = "douyin" }
                    .font(CoreTypography.controlFont)
                    .frame(height: CoreMetrics.controlHeightDefault)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, CoreSpacing.s)
        }

        CoreSettingsSection("数据目录") {
            pathRow("应用数据", "~/Library/Application Support/SYDownload/", showsDivider: true)
            pathRow("缓存", "~/Library/Caches/SYDownload/", showsDivider: true)
            pathRow("下载文件", model.outputDirectory, showsDivider: false)
        }
    }

    private func browserCookieRow(engine: String) -> some View {
        SettingsControlRow("从浏览器读取") {
            HStack(spacing: CoreSpacing.s) {
                SettingsPopupSelector(
                    title: "浏览器",
                    selection: $browserCookieSource,
                    choices: browserCookieChoices
                )

                Button("读取并保存") {
                    Task {
                        await model.importBrowserCookie(
                            engine: engine,
                            browser: browserCookieSource
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .font(CoreTypography.controlFont)
                .frame(height: CoreMetrics.controlHeightDefault)
                .disabled(model.settingsLoading)
            }
        }
    }

    private var browserCookieHelp: some View {
        Text("读取成功后会直接保存到对应引擎配置。首次读取 Chrome、Arc、Edge、Brave 等 Chromium 浏览器时，macOS 可能请求钥匙串授权。")
            .coreTypography(CoreTypography.caption)
            .foregroundStyle(CoreColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func settingsToggleRow(
        _ title: String,
        isOn: Binding<Bool>,
        showsDivider: Bool = true
    ) -> some View {
        SettingsControlRow(title, showsDivider: showsDivider) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(title)
        }
    }

    private func configRow(title: String, path: String, showsDivider: Bool) -> some View {
        CoreSettingsRow(showsDivider: showsDivider) {
            HStack(alignment: .center, spacing: CoreSpacing.m) {
                VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                    Text(title)
                        .coreTypography(CoreTypography.control)
                    Text(path.isEmpty ? "尚未生成" : path)
                        .font(CoreTypography.captionFont.monospaced())
                        .foregroundStyle(path.isEmpty ? CoreColor.textSecondary : CoreColor.textPrimary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Spacer(minLength: CoreSpacing.m)

                Button("打开") { openConfig(path) }
                    .font(CoreTypography.controlFont)
                    .frame(height: CoreMetrics.controlHeightCompact)
                    .disabled(path.isEmpty)
                Button("在 Finder 中显示") { revealConfig(path) }
                    .font(CoreTypography.controlFont)
                    .frame(height: CoreMetrics.controlHeightCompact)
                    .disabled(path.isEmpty)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, CoreSpacing.xs)
        }
    }

    private func pathRow(_ label: String, _ value: String, showsDivider: Bool) -> some View {
        SettingsControlRow(label, showsDivider: showsDivider) {
            Text(value)
                .font(CoreTypography.captionFont.monospaced())
                .foregroundStyle(CoreColor.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }

    private func saveBar(
        title: String,
        isDirty: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: CoreSpacing.m) {
            Label(
                isDirty ? "有未保存更改" : "当前配置已保存", remixSystemImage: isDirty ? "circle.fill" : "checkmark.circle"
            )
            .font(CoreTypography.groupLabelFont)
            .foregroundStyle(isDirty ? CoreColor.accent : CoreColor.textSecondary)

            Spacer(minLength: CoreSpacing.m)

            Button(title, action: action)
                .buttonStyle(.borderedProminent)
                .font(CoreTypography.controlFont)
                .frame(height: CoreMetrics.controlHeightDefault)
                .disabled(model.settingsLoading || !isDirty)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, CoreSpacing.s)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CoreColor.divider)
                .frame(height: CoreMetrics.dividerWidth)
        }
    }

    @ViewBuilder
    private var saveBarForCurrentTab: some View {
        switch tab {
        case .general, .advanced:
            EmptyView()
        case .xhs:
            saveBar(title: "保存小红书设置", isDirty: model.xhsSettingsDirty, action: saveXHSSettings)
        case .douyin:
            saveBar(title: "保存抖音设置", isDirty: model.douyinSettingsDirty, action: saveDouyinSettings)
        }
    }

    private func saveXHSSettings() {
        Task {
            await model.saveXHSSettings()
        }
    }

    private func saveDouyinSettings() {
        Task {
            await model.saveDouyinSettings()
        }
    }

    private func reloadSettings() {
        Task {
            observingEngineSettingsChanges = false
            await model.loadEngineSettings(force: true)
            if model.hasLoadedEngineSettings && !model.settingsStatusIsError {
                model.xhsSettingsDirty = false
                model.douyinSettingsDirty = false
            }
            observingEngineSettingsChanges = true
        }
    }

    private func cookieEditor(
        text: Binding<String>,
        minHeight: CGFloat,
        field: SettingsFocusField,
        isRevealed: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: CoreSpacing.s) {
            Group {
                if isRevealed.wrappedValue {
                    plainTextEditor(text: text, minHeight: minHeight, field: field)
                } else {
                    SecureField("Cookie 已隐藏", text: text)
                        .textFieldStyle(.plain)
                        .font(CoreTypography.captionFont.monospaced())
                        .padding(.horizontal, CoreMetrics.controlHorizontalPadding)
                        .frame(minHeight: CoreMetrics.controlHeightDefault)
                        .coreInputSurface(isFocused: focusedField == field)
                        .focused($focusedField, equals: field)
                }
            }

            HStack(spacing: CoreSpacing.s) {
                Button(isRevealed.wrappedValue ? "隐藏" : "显示") {
                    isRevealed.wrappedValue.toggle()
                }
                .buttonStyle(.borderless)
                .font(CoreTypography.controlFont)

                Button("复制") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text.wrappedValue, forType: .string)
                }
                .buttonStyle(.borderless)
                .font(CoreTypography.controlFont)
                .disabled(text.wrappedValue.isEmpty)

                Button("清除", role: .destructive) {
                    text.wrappedValue = ""
                }
                .buttonStyle(.borderless)
                .font(CoreTypography.controlFont)
                .disabled(text.wrappedValue.isEmpty)

                Spacer(minLength: 0)
            }
        }
    }

    private func plainTextEditor(
        text: Binding<String>,
        minHeight: CGFloat,
        field: SettingsFocusField
    ) -> some View {
        TextEditor(text: text)
            .font(CoreTypography.captionFont.monospaced())
            .scrollContentBackground(.hidden)
            .padding(CoreSpacing.s)
            .frame(minHeight: minHeight)
            .coreInputSurface(isFocused: focusedField == field)
            .focused($focusedField, equals: field)
    }

    private func settingsTabTitle(_ item: SettingsTab) -> String {
        switch item {
        case .xhs where model.xhsSettingsDirty:
            return "\(item.rawValue) •"
        case .douyin where model.douyinSettingsDirty:
            return "\(item.rawValue) •"
        default:
            return item.rawValue
        }
    }

    private func handleSettingsDestination() {
        guard let destination = model.settingsDestination else { return }
        switch destination {
        case .general:
            tab = .general
        case .downloadDirectory:
            tab = .general
            DispatchQueue.main.async {
                focusedField = .downloadDirectory
            }
        case .xhsCookie:
            tab = .xhs
            DispatchQueue.main.async {
                focusedField = .xhsCookie
            }
        case .douyinCookie:
            tab = .douyin
            DispatchQueue.main.async {
                focusedField = .douyinCookie
            }
        }
        model.settingsDestination = nil
    }

    private func chooseFolder() {
        guard model.activeTaskCount == 0 else { return }
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

    private func open(_ raw: String) {
        guard let url = URL(string: raw) else { return }
        NSWorkspace.shared.open(url)
    }
}
#endif
