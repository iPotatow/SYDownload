#if canImport(SwiftUI)
import Foundation
import SwiftUI
import SYDownloadCore

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case download
    case tasks
    case history
    case photos
    case settings

    var id: String { rawValue }
}

enum TaskFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case active = "进行中"
    case completed = "已完成"
    case failed = "失败"

    var id: String { rawValue }
}

enum DownloadTaskState: String, Codable {
    case queued
    case downloading
    case completed
    case failed

    var label: String {
        switch self {
        case .queued: return "等待中"
        case .downloading: return "下载中"
        case .completed: return "已完成"
        case .failed: return "失败"
        }
    }
}

struct DownloadTaskItem: Identifiable {
    let id: UUID
    var title: String
    var platform: DownloadPlatform
    var sourceURL: String
    var state: DownloadTaskState
    var progress: Double?
    var detail: String
    var createdAt: Date
    var outputDirectory: String

    init(
        id: UUID = UUID(),
        title: String,
        platform: DownloadPlatform,
        sourceURL: String,
        state: DownloadTaskState = .queued,
        progress: Double? = nil,
        detail: String = "等待下载…",
        createdAt: Date = .now,
        outputDirectory: String = ""
    ) {
        self.id = id
        self.title = title
        self.platform = platform
        self.sourceURL = sourceURL
        self.state = state
        self.progress = progress
        self.detail = detail
        self.createdAt = createdAt
        self.outputDirectory = outputDirectory
    }
}

struct HistoryItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var platform: DownloadPlatform
    var sourceURL: String
    var outputDirectory: String
    var completedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        platform: DownloadPlatform,
        sourceURL: String,
        outputDirectory: String,
        completedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.platform = platform
        self.sourceURL = sourceURL
        self.outputDirectory = outputDirectory
        self.completedAt = completedAt
    }
}

struct XHSSettingsForm {
    var imageDownload = true
    var videoDownload = true
    var liveDownload = false
    var imageFormat = "JPEG"
    var videoPreference = "resolution"
    var noteFormat = ""
    var folderName = "Download"
    var nameFormat = "发布时间 作者昵称 作品标题"
    var folderMode = false
    var authorArchive = false
    var downloadRecord = true
    var writeMtime = false
    var recordData = false
    var cookie = ""
}

struct DouyinSettingsForm {
    var music = false
    var dynamicCover = false
    var staticCover = false
    var originalQuality = false
    var folderName = "Download"
    var folderMode = false
    var nameFormat = "create_time type nickname desc"
    var descLength = 64
    var nameLength = 128
    var dateFormat = "%Y-%m-%d %H:%M:%S"
    var split = "-"
    var storageFormat = ""
    var maxSize = 0
    var cookie = ""
    var ffmpeg = ""
    var liveQualities = ""
}

private struct LinkValidationResult {
    let link: DetectedDownloadLink
    let ok: Bool
    let message: String
}

private struct PreparedDownload {
    let taskID: UUID
    let validation: LinkValidationResult
}

@MainActor
final class AppModel: ObservableObject {
    typealias BridgeSender = @Sendable (BridgeRequest) async throws -> BridgeResponse

    @Published var selection: AppSection? = .download
    @Published var input = ""
    @Published var outputDirectory: String {
        didSet { defaults.set(outputDirectory, forKey: "SYDownload.outputDirectory") }
    }
    @Published var status = "粘贴链接后即可开始"
    @Published var statusIsError = false
    @Published var detectedPlatform: DownloadPlatform = .unknown
    @Published private(set) var detectedLinks: [DetectedDownloadLink] = []
    @Published var isWorking = false
    @Published var isParsing = false
    @Published var lastDetails: [String: String] = [:]
    @Published private(set) var validatedInput = ""
    @Published var tasks: [DownloadTaskItem] = []
    @Published var history: [HistoryItem] = []
    @Published var taskFilter: TaskFilter = .all
    @Published var historySearch = ""

    @Published var xhsSettings = XHSSettingsForm()
    @Published var douyinSettings = DouyinSettingsForm()
    @Published var settingsStatus = ""
    @Published var settingsStatusIsError = false
    @Published var settingsLoading = false
    @Published var hasLoadedEngineSettings = false
    @Published var xhsSettingsPath = ""
    @Published var douyinSettingsPath = ""

    private let defaults: UserDefaults
    private let sendBridge: BridgeSender
    private let historyKey = "SYDownload.history.v1"

    init(
        userDefaults: UserDefaults = .standard,
        bridgeSend: @escaping BridgeSender = { request in
            try await BridgeClient().send(request)
        }
    ) {
        defaults = userDefaults
        sendBridge = bridgeSend
        outputDirectory = userDefaults.string(forKey: "SYDownload.outputDirectory")
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
                .first?.appendingPathComponent("SYDownload").path
            ?? "~/Downloads/SYDownload"
        loadHistory()
    }

    var filteredTasks: [DownloadTaskItem] {
        switch taskFilter {
        case .all: return tasks
        case .active: return tasks.filter { $0.state == .queued || $0.state == .downloading }
        case .completed: return tasks.filter { $0.state == .completed }
        case .failed: return tasks.filter { $0.state == .failed }
        }
    }

    var filteredHistory: [HistoryItem] {
        let query = historySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return history }
        return history.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.sourceURL.localizedCaseInsensitiveContains(query)
                || $0.platform.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    var supportedLinkCount: Int {
        detectedLinks.filter { $0.platform != .unknown }.count
    }

    var unsupportedLinkCount: Int {
        detectedLinks.filter { $0.platform == .unknown }.count
    }

    var hasSupportedLinks: Bool {
        supportedLinkCount > 0
    }

    var hasXHSLinks: Bool {
        detectedLinks.contains { $0.platform == .xiaohongshu }
    }

    var hasDouyinLinks: Bool {
        detectedLinks.contains { $0.platform == .douyin }
    }

    func detectLocally() {
        let normalizedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !validatedInput.isEmpty && normalizedInput != validatedInput {
            lastDetails = [:]
            validatedInput = ""
        }

        let newLinks = PlatformDetector.extractLinks(input)
        if newLinks != detectedLinks {
            lastDetails = [:]
            validatedInput = ""
        }
        detectedLinks = newLinks
        detectedPlatform = newLinks.first(where: { $0.platform != .unknown })?.platform ?? .unknown

        if normalizedInput.isEmpty {
            status = "粘贴链接后即可开始"
            statusIsError = false
        } else if newLinks.isEmpty {
            status = "暂未识别到链接"
            statusIsError = true
        } else if supportedLinkCount == 0 {
            status = "识别到 \(newLinks.count) 个链接，但没有支持的平台"
            statusIsError = true
        } else {
            status = detectionSummary
            statusIsError = false
        }
    }

    func clearInput() {
        input = ""
        detectedPlatform = .unknown
        detectedLinks = []
        lastDetails = [:]
        validatedInput = ""
        status = "粘贴链接后即可开始"
        statusIsError = false
    }

    func validateEngine() async {
        detectLocally()
        guard hasSupportedLinks else { return }

        let expectedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let links = detectedLinks
        guard let results = await validateLinks(links, expectedInput: expectedInput) else { return }

        let supportedFailures = results.filter {
            $0.link.platform != .unknown && !$0.ok
        }
        let unsupported = results.filter { $0.link.platform == .unknown }.count
        let downloadable = results.filter { $0.link.platform != .unknown && $0.ok }.count

        validatedInput = supportedFailures.isEmpty ? expectedInput : ""

        if supportedFailures.isEmpty && unsupported == 0 {
            status = results.count == 1
                ? "链接检查通过"
                : "已检查 \(results.count) 个链接，均可下载"
            statusIsError = false
            return
        }

        var parts = ["\(downloadable) 个可下载"]
        if !supportedFailures.isEmpty {
            parts.append("\(supportedFailures.count) 个检查失败")
        }
        if unsupported > 0 {
            parts.append("\(unsupported) 个不支持")
        }
        status = "已检查 \(results.count) 个链接：" + parts.joined(separator: "，")
        statusIsError = downloadable == 0 || !supportedFailures.isEmpty
    }

    func runDownload() async {
        guard !isWorking, !isParsing else { return }
        detectLocally()
        guard hasSupportedLinks else { return }

        let requestedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedLinks = detectedLinks
        let destination = outputDirectory

        isWorking = true
        defer { isWorking = false }

        let validations: [LinkValidationResult]
        if validatedInput == requestedInput {
            validations = requestedLinks.map { link in
                LinkValidationResult(
                    link: link,
                    ok: link.platform != .unknown,
                    message: link.platform == .unknown ? "不支持此链接平台。" : "链接检查通过"
                )
            }
        } else {
            guard let results = await validateLinks(requestedLinks, expectedInput: requestedInput) else {
                return
            }
            validations = results
            let supportedFailures = results.contains {
                $0.link.platform != .unknown && !$0.ok
            }
            if !supportedFailures {
                validatedInput = requestedInput
            }
        }

        guard input.trimmingCharacters(in: .whitespacesAndNewlines) == requestedInput else {
            return
        }

        let prepared = validations.map {
            PreparedDownload(taskID: UUID(), validation: $0)
        }
        let newTasks = prepared.map { preparedItem in
            let validation = preparedItem.validation
            return DownloadTaskItem(
                id: preparedItem.taskID,
                title: taskTitle(for: validation.link),
                platform: validation.link.platform,
                sourceURL: validation.link.url,
                state: validation.ok ? .queued : .failed,
                progress: nil,
                detail: validation.ok ? "等待下载…" : validation.message,
                outputDirectory: destination
            )
        }

        tasks.insert(contentsOf: newTasks, at: 0)
        selection = .tasks

        let downloadable = prepared.filter { $0.validation.ok }
        var successCount = 0
        var failedCount = prepared.count - downloadable.count
        var completedDownloadCount = 0
        var newHistory: [HistoryItem] = []
        var lastFailureMessage = validations.first(where: { !$0.ok })?.message

        if downloadable.isEmpty {
            status = "没有可下载的链接"
            statusIsError = true
            return
        }

        for preparedItem in downloadable {
            completedDownloadCount += 1
            let link = preparedItem.validation.link
            let title = taskTitle(for: link)

            updateTask(preparedItem.taskID) { task in
                task.state = .downloading
                task.detail = "正在调用 \(link.platform.displayName) 下载引擎…"
            }

            if downloadable.count == 1 {
                status = "正在下载…"
            } else {
                status = "正在下载 \(completedDownloadCount)/\(downloadable.count)…"
            }
            statusIsError = false

            do {
                let response = try await sendBridge(.init(
                    command: "download",
                    url: link.url,
                    outputDirectory: destination
                ))
                lastDetails = response.details ?? [:]
                updateTask(preparedItem.taskID) { task in
                    task.state = response.ok ? .completed : .failed
                    task.progress = response.ok ? 1.0 : nil
                    task.detail = response.ok ? "下载完成" : response.message
                }

                if response.ok {
                    successCount += 1
                    newHistory.append(
                        HistoryItem(
                            title: title,
                            platform: link.platform,
                            sourceURL: link.url,
                            outputDirectory: destination
                        )
                    )
                } else {
                    failedCount += 1
                    lastFailureMessage = response.message
                }
            } catch {
                failedCount += 1
                lastFailureMessage = error.localizedDescription
                updateTask(preparedItem.taskID) { task in
                    task.state = .failed
                    task.progress = nil
                    task.detail = error.localizedDescription
                }
            }
        }

        if !newHistory.isEmpty {
            history.insert(contentsOf: newHistory, at: 0)
            if history.count > 100 {
                history.removeLast(history.count - 100)
            }
            persistHistory()
        }

        if prepared.count == 1 {
            status = successCount == 1 ? "下载完成" : (lastFailureMessage ?? "下载失败")
        } else {
            status = "批量下载完成：\(successCount) 成功，\(failedCount) 失败"
        }
        statusIsError = failedCount > 0
    }

    func loadEngineSettings(force: Bool = false) async {
        guard force || !hasLoadedEngineSettings else { return }
        settingsLoading = true
        defer { settingsLoading = false }

        do {
            let xhs = try await sendBridge(.init(command: "settings_get", engine: "xiaohongshu"))
            guard xhs.ok else {
                settingsStatus = xhs.message
                settingsStatusIsError = true
                return
            }
            applyXHSSettings(xhs.details ?? [:])

            let douyin = try await sendBridge(.init(command: "settings_get", engine: "douyin"))
            guard douyin.ok else {
                settingsStatus = douyin.message
                settingsStatusIsError = true
                return
            }
            applyDouyinSettings(douyin.details ?? [:])

            hasLoadedEngineSettings = true
            settingsStatus = "已读取原始项目配置。"
            settingsStatusIsError = false
        } catch {
            settingsStatus = error.localizedDescription
            settingsStatusIsError = true
        }
    }

    func saveXHSSettings() async {
        let values: [String: Any] = [
            "work_path": outputDirectory,
            "image_download": xhsSettings.imageDownload,
            "video_download": xhsSettings.videoDownload,
            "live_download": xhsSettings.liveDownload,
            "image_format": xhsSettings.imageFormat,
            "video_preference": xhsSettings.videoPreference,
            "note_format": xhsSettings.noteFormat,
            "folder_name": xhsSettings.folderName,
            "name_format": xhsSettings.nameFormat,
            "folder_mode": xhsSettings.folderMode,
            "author_archive": xhsSettings.authorArchive,
            "download_record": xhsSettings.downloadRecord,
            "write_mtime": xhsSettings.writeMtime,
            "record_data": xhsSettings.recordData,
            "cookie": xhsSettings.cookie,
        ]
        await saveEngineSettings(engine: "xiaohongshu", values: values)
    }

    func saveDouyinSettings() async {
        let values: [String: Any] = [
            "root": outputDirectory,
            "music": douyinSettings.music,
            "dynamic_cover": douyinSettings.dynamicCover,
            "static_cover": douyinSettings.staticCover,
            "original_quality": douyinSettings.originalQuality,
            "folder_name": douyinSettings.folderName,
            "folder_mode": douyinSettings.folderMode,
            "name_format": douyinSettings.nameFormat,
            "desc_length": douyinSettings.descLength,
            "name_length": douyinSettings.nameLength,
            "date_format": douyinSettings.dateFormat,
            "split": douyinSettings.split,
            "storage_format": douyinSettings.storageFormat,
            "max_size": douyinSettings.maxSize,
            "cookie": douyinSettings.cookie,
            "ffmpeg": douyinSettings.ffmpeg,
            "live_qualities": douyinSettings.liveQualities,
        ]
        await saveEngineSettings(engine: "douyin", values: values)
    }

    func resetEngineSettings(_ engine: String) async {
        settingsLoading = true
        defer { settingsLoading = false }
        do {
            let response = try await sendBridge(.init(command: "settings_reset", engine: engine))
            settingsStatus = response.message
            if response.ok {
                settingsStatusIsError = false
                hasLoadedEngineSettings = false
                await loadEngineSettings(force: true)
            } else {
                settingsStatusIsError = true
            }
        } catch {
            settingsStatus = error.localizedDescription
            settingsStatusIsError = true
        }
    }

    func clearCompletedTasks() {
        tasks.removeAll { $0.state == .completed }
    }

    func removeTask(_ id: UUID) {
        tasks.removeAll { $0.id == id && $0.state != .downloading }
    }

    func retryTask(_ task: DownloadTaskItem) {
        guard !isWorking else { return }
        input = task.sourceURL
        validatedInput = ""
        detectLocally()
        selection = .download
        status = "已载入失败任务，可重新检查后下载"
    }

    func removeHistory(_ id: UUID) {
        history.removeAll { $0.id == id }
        persistHistory()
    }

    func useHistory(_ item: HistoryItem) {
        input = item.sourceURL
        outputDirectory = item.outputDirectory
        validatedInput = ""
        detectLocally()
        selection = .download
        status = "已载入历史链接，可重新检查"
    }

    private var detectionSummary: String {
        let xhsCount = detectedLinks.filter { $0.platform == .xiaohongshu }.count
        let douyinCount = detectedLinks.filter { $0.platform == .douyin }.count
        var parts: [String] = []
        if xhsCount > 0 { parts.append("小红书 \(xhsCount)") }
        if douyinCount > 0 { parts.append("抖音 \(douyinCount)") }

        var result = "已识别 \(supportedLinkCount) 个支持链接"
        if !parts.isEmpty {
            result += "：" + parts.joined(separator: " · ")
        }
        if unsupportedLinkCount > 0 {
            result += "，另有 \(unsupportedLinkCount) 个不支持链接"
        }
        return result
    }

    private func validateLinks(
        _ links: [DetectedDownloadLink],
        expectedInput: String
    ) async -> [LinkValidationResult]? {
        isParsing = true
        defer { isParsing = false }

        var results: [LinkValidationResult] = []
        for link in links {
            guard input.trimmingCharacters(in: .whitespacesAndNewlines) == expectedInput else {
                return nil
            }

            if link.platform == .unknown {
                results.append(
                    LinkValidationResult(
                        link: link,
                        ok: false,
                        message: "不支持此链接平台。"
                    )
                )
                continue
            }

            do {
                let response = try await sendBridge(.init(command: "validate", url: link.url))
                guard input.trimmingCharacters(in: .whitespacesAndNewlines) == expectedInput else {
                    return nil
                }
                lastDetails = response.details ?? [:]
                results.append(
                    LinkValidationResult(
                        link: link,
                        ok: response.ok,
                        message: response.message
                    )
                )
            } catch {
                guard input.trimmingCharacters(in: .whitespacesAndNewlines) == expectedInput else {
                    return nil
                }
                lastDetails = [:]
                results.append(
                    LinkValidationResult(
                        link: link,
                        ok: false,
                        message: error.localizedDescription
                    )
                )
            }
        }
        return results
    }

    private func taskTitle(for link: DetectedDownloadLink) -> String {
        guard let url = URL(string: link.url) else {
            return "\(link.platform.displayName)下载任务"
        }
        let identifier = url.pathComponents
            .reversed()
            .first { $0 != "/" && !$0.isEmpty }
        guard let identifier else {
            return "\(link.platform.displayName)下载任务"
        }
        return "\(link.platform.displayName) · \(identifier)"
    }

    private func saveEngineSettings(engine: String, values: [String: Any]) async {
        guard JSONSerialization.isValidJSONObject(values),
              let data = try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8)
        else {
            settingsStatus = "设置数据无法编码。"
            settingsStatusIsError = true
            return
        }

        settingsLoading = true
        defer { settingsLoading = false }
        do {
            let response = try await sendBridge(.init(
                command: "settings_update",
                engine: engine,
                settingsJSON: json
            ))
            settingsStatus = response.message
            settingsStatusIsError = !response.ok
            if response.ok {
                if engine == "xiaohongshu" {
                    xhsSettingsPath = response.details?["config_path"] ?? xhsSettingsPath
                } else {
                    douyinSettingsPath = response.details?["config_path"] ?? douyinSettingsPath
                }
            }
        } catch {
            settingsStatus = error.localizedDescription
            settingsStatusIsError = true
        }
    }

    private func applyXHSSettings(_ details: [String: String]) {
        xhsSettings.imageDownload = boolValue(details["image_download"], fallback: true)
        xhsSettings.videoDownload = boolValue(details["video_download"], fallback: true)
        xhsSettings.liveDownload = boolValue(details["live_download"], fallback: false)
        xhsSettings.imageFormat = details["image_format"] ?? "JPEG"
        xhsSettings.videoPreference = details["video_preference"] ?? "resolution"
        xhsSettings.noteFormat = details["note_format"] ?? ""
        xhsSettings.folderName = details["folder_name"] ?? "Download"
        xhsSettings.nameFormat = details["name_format"] ?? "发布时间 作者昵称 作品标题"
        xhsSettings.folderMode = boolValue(details["folder_mode"], fallback: false)
        xhsSettings.authorArchive = boolValue(details["author_archive"], fallback: false)
        xhsSettings.downloadRecord = boolValue(details["download_record"], fallback: true)
        xhsSettings.writeMtime = boolValue(details["write_mtime"], fallback: false)
        xhsSettings.recordData = boolValue(details["record_data"], fallback: false)
        xhsSettings.cookie = details["cookie"] ?? ""
        xhsSettingsPath = details["config_path"] ?? ""
    }

    private func applyDouyinSettings(_ details: [String: String]) {
        douyinSettings.music = boolValue(details["music"], fallback: false)
        douyinSettings.dynamicCover = boolValue(details["dynamic_cover"], fallback: false)
        douyinSettings.staticCover = boolValue(details["static_cover"], fallback: false)
        douyinSettings.originalQuality = boolValue(details["original_quality"], fallback: false)
        douyinSettings.folderName = details["folder_name"] ?? "Download"
        douyinSettings.folderMode = boolValue(details["folder_mode"], fallback: false)
        douyinSettings.nameFormat = details["name_format"] ?? "create_time type nickname desc"
        douyinSettings.descLength = Int(details["desc_length"] ?? "") ?? 64
        douyinSettings.nameLength = Int(details["name_length"] ?? "") ?? 128
        douyinSettings.dateFormat = details["date_format"] ?? "%Y-%m-%d %H:%M:%S"
        douyinSettings.split = details["split"] ?? "-"
        douyinSettings.storageFormat = details["storage_format"] ?? ""
        douyinSettings.maxSize = Int(details["max_size"] ?? "") ?? 0
        douyinSettings.cookie = details["cookie"] ?? ""
        douyinSettings.ffmpeg = details["ffmpeg"] ?? ""
        douyinSettings.liveQualities = details["live_qualities"] ?? ""
        douyinSettingsPath = details["config_path"] ?? ""
    }

    private func boolValue(_ value: String?, fallback: Bool) -> Bool {
        guard let value else { return fallback }
        return ["true", "1", "yes", "on"].contains(value.lowercased())
    }

    private func updateTask(_ id: UUID, mutation: (inout DownloadTaskItem) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        mutation(&tasks[index])
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: historyKey)
    }

    private func loadHistory() {
        if let data = defaults.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            history = decoded
            return
        }

        history = []
    }
}
#endif
