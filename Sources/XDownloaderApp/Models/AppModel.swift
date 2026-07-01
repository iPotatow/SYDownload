#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XDownloaderCore

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case download
    case tasks
    case history
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

    init(
        id: UUID = UUID(),
        title: String,
        platform: DownloadPlatform,
        sourceURL: String,
        state: DownloadTaskState = .queued,
        progress: Double? = nil,
        detail: String = "等待下载…",
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.platform = platform
        self.sourceURL = sourceURL
        self.state = state
        self.progress = progress
        self.detail = detail
        self.createdAt = createdAt
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

struct ParsedPreview: Equatable {
    var platform: DownloadPlatform
    var title: String
    var author: String
    var summary: String
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
    var cookieTikTok = ""
    var ffmpeg = ""
    var liveQualities = ""
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selection: AppSection? = .download
    @Published var input = ""
    @Published var outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
        .first?
        .appendingPathComponent("XDownloader")
        .path ?? "~/Downloads/XDownloader"
    @Published var status = "粘贴链接后即可开始"
    @Published var detectedPlatform: DownloadPlatform = .unknown
    @Published var isWorking = false
    @Published var isParsing = false
    @Published var lastDetails: [String: String] = [:]
    @Published var preview: ParsedPreview?
    @Published var tasks: [DownloadTaskItem] = []
    @Published var history: [HistoryItem] = []
    @Published var taskFilter: TaskFilter = .all
    @Published var historySearch = ""

    @Published var xhsSettings = XHSSettingsForm()
    @Published var douyinSettings = DouyinSettingsForm()
    @Published var settingsStatus = ""
    @Published var settingsLoading = false
    @Published var hasLoadedEngineSettings = false
    @Published var xhsSettingsPath = ""
    @Published var douyinSettingsPath = ""

    private let bridge = BridgeClient()
    private let historyKey = "XDownloader.history.v1"

    init() {
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

    func detectLocally() {
        let newPlatform = PlatformDetector.detect(input)
        if newPlatform != detectedPlatform {
            preview = nil
            lastDetails = [:]
        }
        detectedPlatform = newPlatform

        if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            status = "粘贴链接后即可开始"
        } else if newPlatform == .unknown {
            status = "暂未识别到支持的平台链接"
        } else {
            status = "已识别：\(newPlatform.displayName)"
        }
    }

    func clearInput() {
        input = ""
        detectedPlatform = .unknown
        preview = nil
        lastDetails = [:]
        status = "粘贴链接后即可开始"
    }

    func validateEngine() async {
        detectLocally()
        guard detectedPlatform != .unknown else { return }
        isParsing = true
        defer { isParsing = false }

        do {
            let response = try await bridge.send(.init(command: "validate", url: input))
            status = response.message
            lastDetails = response.details ?? [:]
            if response.ok {
                preview = ParsedPreview(
                    platform: response.platform ?? detectedPlatform,
                    title: "\((response.platform ?? detectedPlatform).displayName)内容已解析",
                    author: "链接已就绪",
                    summary: "已完成平台识别与下载引擎检查，可直接开始下载。"
                )
            } else {
                preview = nil
            }
        } catch {
            preview = nil
            status = error.localizedDescription
        }
    }

    func runDownload() async {
        detectLocally()
        guard detectedPlatform != .unknown else { return }

        if preview == nil {
            await validateEngine()
            guard preview != nil else { return }
        }

        let platform = detectedPlatform
        let sourceURL = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = preview?.title ?? "\(platform.displayName)下载任务"
        let taskID = UUID()
        let item = DownloadTaskItem(
            id: taskID,
            title: title,
            platform: platform,
            sourceURL: sourceURL,
            state: .downloading,
            progress: nil,
            detail: "正在调用 \(platform.displayName) 下载引擎…"
        )
        tasks.insert(item, at: 0)
        selection = .tasks
        isWorking = true
        status = "正在下载…"

        do {
            let response = try await bridge.send(.init(
                command: "download",
                url: sourceURL,
                outputDirectory: outputDirectory
            ))
            lastDetails = response.details ?? [:]
            status = response.message
            updateTask(taskID) { task in
                task.state = response.ok ? .completed : .failed
                task.progress = response.ok ? 1.0 : nil
                task.detail = response.ok ? "下载完成" : response.message
            }

            if response.ok {
                history.insert(
                    HistoryItem(
                        title: title,
                        platform: platform,
                        sourceURL: sourceURL,
                        outputDirectory: outputDirectory
                    ),
                    at: 0
                )
                if history.count > 100 {
                    history.removeLast(history.count - 100)
                }
                persistHistory()
            }
        } catch {
            status = error.localizedDescription
            updateTask(taskID) { task in
                task.state = .failed
                task.progress = nil
                task.detail = error.localizedDescription
            }
        }

        isWorking = false
    }

    func loadEngineSettings(force: Bool = false) async {
        guard force || !hasLoadedEngineSettings else { return }
        settingsLoading = true
        defer { settingsLoading = false }

        do {
            let xhs = try await bridge.send(.init(command: "settings_get", engine: "xiaohongshu"))
            guard xhs.ok else {
                settingsStatus = xhs.message
                return
            }
            applyXHSSettings(xhs.details ?? [:])

            let douyin = try await bridge.send(.init(command: "settings_get", engine: "douyin"))
            guard douyin.ok else {
                settingsStatus = douyin.message
                return
            }
            applyDouyinSettings(douyin.details ?? [:])

            hasLoadedEngineSettings = true
            settingsStatus = "已读取原始项目配置。"
        } catch {
            settingsStatus = error.localizedDescription
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
            "cookie_tiktok": douyinSettings.cookieTikTok,
            "ffmpeg": douyinSettings.ffmpeg,
            "live_qualities": douyinSettings.liveQualities,
        ]
        await saveEngineSettings(engine: "douyin", values: values)
    }

    func resetEngineSettings(_ engine: String) async {
        settingsLoading = true
        defer { settingsLoading = false }
        do {
            let response = try await bridge.send(.init(command: "settings_reset", engine: engine))
            settingsStatus = response.message
            if response.ok {
                hasLoadedEngineSettings = false
                await loadEngineSettings(force: true)
            }
        } catch {
            settingsStatus = error.localizedDescription
        }
    }

    func clearCompletedTasks() {
        tasks.removeAll { $0.state == .completed }
    }

    func removeTask(_ id: UUID) {
        tasks.removeAll { $0.id == id && $0.state != .downloading }
    }

    func removeHistory(_ id: UUID) {
        history.removeAll { $0.id == id }
        persistHistory()
    }

    func useHistory(_ item: HistoryItem) {
        input = item.sourceURL
        outputDirectory = item.outputDirectory
        detectedPlatform = item.platform
        preview = nil
        selection = .download
        status = "已载入历史链接，可重新解析"
    }

    private func saveEngineSettings(engine: String, values: [String: Any]) async {
        guard JSONSerialization.isValidJSONObject(values),
              let data = try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8)
        else {
            settingsStatus = "设置数据无法编码。"
            return
        }

        settingsLoading = true
        defer { settingsLoading = false }
        do {
            let response = try await bridge.send(.init(
                command: "settings_update",
                engine: engine,
                settingsJSON: json
            ))
            settingsStatus = response.message
            if response.ok {
                if engine == "xiaohongshu" {
                    xhsSettingsPath = response.details?["config_path"] ?? xhsSettingsPath
                } else {
                    douyinSettingsPath = response.details?["config_path"] ?? douyinSettingsPath
                }
            }
        } catch {
            settingsStatus = error.localizedDescription
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
        douyinSettings.cookieTikTok = details["cookie_tiktok"] ?? ""
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
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data)
        else { return }
        history = decoded
    }
}
#endif
