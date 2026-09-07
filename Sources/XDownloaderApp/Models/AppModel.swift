#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XDownloaderCore

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case download
    case tasks
    case history
    case xiaohongshu
    case douyinTikTok
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

    @Published var includeVideo = true
    @Published var includeCover = true
    @Published var includeAudio = false
    @Published var includeText = false

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

    func focusPlatform(_ platform: DownloadPlatform) {
        selection = .download
        detectedPlatform = platform
        preview = nil
        if input.isEmpty {
            status = "已切换到 \(platform.displayName)，请粘贴链接"
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
