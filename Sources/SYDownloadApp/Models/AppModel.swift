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
    case cancelled

    var label: String {
        switch self {
        case .queued: return "等待中"
        case .downloading: return "下载中"
        case .completed: return "已完成"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }
}

enum DownloadFailureKind: String, Codable, Sendable {
    case unsupported
    case validation
    case timeout
    case cancelled
    case network
    case auth
    case rateLimited = "rate_limited"
    case notFound = "not_found"
    case disk
    case verification
    case engine
    case unknown

    var label: String {
        switch self {
        case .unsupported: return "平台不支持"
        case .validation: return "链接检查失败"
        case .timeout: return "任务超时"
        case .cancelled: return "已取消"
        case .network: return "网络错误"
        case .auth: return "Cookie/登录状态异常"
        case .rateLimited: return "平台风控/限流"
        case .notFound: return "作品不可用"
        case .disk: return "磁盘写入错误"
        case .verification: return "文件校验失败"
        case .engine: return "下载引擎错误"
        case .unknown: return "未知错误"
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
    var failureKind: DownloadFailureKind?
    var bytesWritten: Int64
    var fileCount: Int

    init(
        id: UUID = UUID(),
        title: String,
        platform: DownloadPlatform,
        sourceURL: String,
        state: DownloadTaskState = .queued,
        progress: Double? = nil,
        detail: String = "等待下载…",
        createdAt: Date = .now,
        outputDirectory: String = "",
        failureKind: DownloadFailureKind? = nil,
        bytesWritten: Int64 = 0,
        fileCount: Int = 0
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
        self.failureKind = failureKind
        self.bytesWritten = bytesWritten
        self.fileCount = fileCount
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
}

private struct LinkValidationResult: Sendable {
    let link: DetectedDownloadLink
    let ok: Bool
    let message: String
}

private struct PreparedDownload: Sendable {
    let taskID: UUID
    let validation: LinkValidationResult
    let batchIndex: Int
}

private struct DownloadExecutionResult: Sendable {
    let prepared: PreparedDownload
    let response: BridgeResponse?
    let failureKind: DownloadFailureKind?
    let failureMessage: String?
}

private struct DownloadOutputContext: Sendable {
    let bridgeDirectory: String
    let folderName: String
}

@MainActor
final class AppModel: ObservableObject {
    typealias BridgeSender = @Sendable (BridgeRequest) async throws -> BridgeResponse
    typealias BridgeStreamingSender = @Sendable (
        BridgeRequest,
        @escaping @Sendable (BridgeProgressEvent) -> Void
    ) async throws -> BridgeResponse

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
    private let sendBridgeStreaming: BridgeStreamingSender
    private let historyKey = "SYDownload.history.v1"
    private let maxConcurrentDownloads = 3
    private let downloadTimeoutSeconds: Double = 15 * 60

    init(
        userDefaults: UserDefaults = .standard,
        bridgeStreamingSend: @escaping BridgeStreamingSender = { request, onProgress in
            try await BridgeClient().sendStreaming(request, onProgress: onProgress)
        },
        bridgeSend: @escaping BridgeSender = { request in
            try await BridgeClient().send(request)
        }
    ) {
        defaults = userDefaults
        sendBridge = bridgeSend
        sendBridgeStreaming = bridgeStreamingSend
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
        case .failed: return tasks.filter { $0.state == .failed || $0.state == .cancelled }
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
        guard let results = await validateLinks(
            links,
            expectedInput: expectedInput,
            abortOnInputChange: true
        ) else { return }

        let supportedFailures = results.filter {
            $0.link.platform != .unknown && !$0.ok
        }
        let unsupported = results.filter { $0.link.platform == .unknown }.count
        let downloadable = results.filter { $0.link.platform != .unknown && $0.ok }.count

        validatedInput = supportedFailures.isEmpty ? expectedInput : ""

        if supportedFailures.isEmpty && unsupported == 0 {
            status = results.count == 1
                ? "下载环境检查通过"
                : "已检查 \(results.count) 个链接涉及的下载环境，均可用"
            statusIsError = false
            return
        }

        var parts = ["\(downloadable) 个可下载"]
        if !supportedFailures.isEmpty {
            parts.append("\(supportedFailures.count) 个环境检查失败")
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
        let taskIDs = requestedLinks.map { _ in UUID() }

        isWorking = true
        defer { isWorking = false }

        let newTasks = zip(taskIDs, requestedLinks).map { pair in
            let (taskID, link) = pair
            let supported = link.platform != .unknown
            return DownloadTaskItem(
                id: taskID,
                title: taskTitle(for: link),
                platform: link.platform,
                sourceURL: link.url,
                state: supported ? .queued : .failed,
                progress: nil,
                detail: supported ? "等待下载环境检查…" : "不支持此链接平台。",
                outputDirectory: destination,
                failureKind: supported ? nil : .unsupported
            )
        }
        tasks.insert(contentsOf: newTasks, at: 0)
        selection = .tasks

        guard let outputContext = downloadOutputContext(for: destination) else {
            for taskID in taskIDs {
                updateTask(taskID) { task in
                    guard task.state == .queued else { return }
                    task.state = .failed
                    task.failureKind = .disk
                    task.detail = "下载目录必须是具体文件夹，不能直接使用磁盘根目录。"
                }
            }
            status = "下载目录无效"
            statusIsError = true
            return
        }

        let validations: [LinkValidationResult]
        if validatedInput == requestedInput {
            validations = requestedLinks.map { link in
                LinkValidationResult(
                    link: link,
                    ok: link.platform != .unknown,
                    message: link.platform == .unknown ? "不支持此链接平台。" : "下载环境检查通过"
                )
            }
        } else if let results = await validateLinks(
            requestedLinks,
            expectedInput: requestedInput,
            abortOnInputChange: false
        ) {
            validations = results
            let supportedFailures = results.contains {
                $0.link.platform != .unknown && !$0.ok
            }
            if !supportedFailures,
               input.trimmingCharacters(in: .whitespacesAndNewlines) == requestedInput {
                validatedInput = requestedInput
            }
        } else {
            for taskID in taskIDs {
                updateTask(taskID) { task in
                    guard task.state == .queued else { return }
                    task.state = .failed
                    task.failureKind = .validation
                    task.detail = "下载环境检查已取消。"
                }
            }
            status = "下载环境检查已取消"
            statusIsError = true
            return
        }

        let prepared = validations.enumerated().map { index, validation in
            PreparedDownload(
                taskID: taskIDs[index],
                validation: validation,
                batchIndex: index
            )
        }

        for preparedItem in prepared where !preparedItem.validation.ok {
            updateTask(preparedItem.taskID) { task in
                guard task.state == .queued else { return }
                task.state = .failed
                task.progress = nil
                task.failureKind = preparedItem.validation.link.platform == .unknown
                    ? .unsupported
                    : .validation
                task.detail = preparedItem.validation.message
            }
        }

        let preflightDownloadable = prepared.filter { $0.validation.ok }
        let preparationFailures = await prepareDownloadFolders(
            platforms: Set(preflightDownloadable.map { $0.validation.link.platform }),
            folderName: outputContext.folderName
        )

        if !preparationFailures.isEmpty {
            for preparedItem in preflightDownloadable {
                if let message = preparationFailures[preparedItem.validation.link.platform] {
                    updateTask(preparedItem.taskID) { task in
                        guard task.state == .queued else { return }
                        task.state = .failed
                        task.progress = nil
                        task.failureKind = .validation
                        task.detail = "下载目录准备失败：\(message)"
                    }
                }
            }
        }

        let downloadable = preflightDownloadable.filter {
            preparationFailures[$0.validation.link.platform] == nil
        }
        if downloadable.isEmpty {
            status = "没有可下载的链接"
            statusIsError = true
            return
        }

        status = downloadable.count == 1
            ? "正在下载…"
            : "正在下载 \(downloadable.count) 个任务（最多 \(maxConcurrentDownloads) 个并行）…"
        statusIsError = false

        let limiter = AsyncSemaphore(value: maxConcurrentDownloads)
        let streamingSender = sendBridgeStreaming
        let timeoutSeconds = downloadTimeoutSeconds
        let bridgeDirectory = outputContext.bridgeDirectory
        var results: [DownloadExecutionResult] = []

        await withTaskGroup(of: DownloadExecutionResult.self) { group in
            for preparedItem in downloadable {
                group.addTask { [weak self, streamingSender] in
                    await limiter.acquire()
                    guard let self else {
                        await limiter.release()
                        return DownloadExecutionResult(
                            prepared: preparedItem,
                            response: nil,
                            failureKind: .unknown,
                            failureMessage: "下载任务已失去应用上下文。"
                        )
                    }

                    let shouldStart = await self.markTaskStarted(
                        preparedItem.taskID,
                        platform: preparedItem.validation.link.platform
                    )
                    guard shouldStart else {
                        await limiter.release()
                        return DownloadExecutionResult(
                            prepared: preparedItem,
                            response: nil,
                            failureKind: .cancelled,
                            failureMessage: "下载任务已取消。"
                        )
                    }

                    let request = BridgeRequest(
                        id: preparedItem.taskID,
                        command: "download",
                        url: preparedItem.validation.link.url,
                        outputDirectory: bridgeDirectory,
                        timeoutSeconds: timeoutSeconds
                    )
                    do {
                        let response = try await streamingSender(request) { event in
                            Task { @MainActor [weak self] in
                                self?.applyProgress(event, to: preparedItem.taskID)
                            }
                        }
                        await limiter.release()
                        return DownloadExecutionResult(
                            prepared: preparedItem,
                            response: response,
                            failureKind: nil,
                            failureMessage: nil
                        )
                    } catch {
                        await limiter.release()
                        let failure = classifyDownloadError(error)
                        return DownloadExecutionResult(
                            prepared: preparedItem,
                            response: nil,
                            failureKind: failure.kind,
                            failureMessage: failure.message
                        )
                    }
                }
            }

            for await result in group {
                results.append(result)
                applyDownloadResult(result)
            }
        }

        let successfulResults = results
            .filter { result in
                guard result.response?.ok == true else { return false }
                return tasks.first(where: { $0.id == result.prepared.taskID })?.state == .completed
            }
            .sorted { $0.prepared.batchIndex < $1.prepared.batchIndex }

        if !successfulResults.isEmpty {
            let newHistory = successfulResults.map { result in
                let link = result.prepared.validation.link
                return HistoryItem(
                    title: taskTitle(for: link),
                    platform: link.platform,
                    sourceURL: link.url,
                    outputDirectory: destination
                )
            }
            history.insert(contentsOf: newHistory, at: 0)
            if history.count > 100 {
                history.removeLast(history.count - 100)
            }
            persistHistory()
        }

        let batchTasks = prepared.compactMap { preparedItem in
            tasks.first(where: { $0.id == preparedItem.taskID })
        }
        let successCount = batchTasks.filter { $0.state == .completed }.count
        let failedCount = batchTasks.filter { $0.state == .failed }.count
        let cancelledCount = batchTasks.filter { $0.state == .cancelled }.count

        if prepared.count == 1, let onlyTask = batchTasks.first {
            switch onlyTask.state {
            case .completed:
                status = "下载完成"
                statusIsError = false
            case .cancelled:
                status = "下载已取消"
                statusIsError = false
            case .failed:
                status = onlyTask.detail
                statusIsError = true
            case .queued, .downloading:
                status = onlyTask.detail
                statusIsError = false
            }
        } else {
            var summary = "批量下载完成：\(successCount) 成功，\(failedCount) 失败"
            if cancelledCount > 0 {
                summary += "，\(cancelledCount) 取消"
            }
            status = summary
            statusIsError = failedCount > 0
        }
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
            "image_download": xhsSettings.imageDownload,
            "video_download": xhsSettings.videoDownload,
            "live_download": xhsSettings.liveDownload,
            "image_format": xhsSettings.imageFormat,
            "video_preference": xhsSettings.videoPreference,
            "note_format": xhsSettings.noteFormat,
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
            "music": douyinSettings.music,
            "dynamic_cover": douyinSettings.dynamicCover,
            "static_cover": douyinSettings.staticCover,
            "original_quality": douyinSettings.originalQuality,
            "folder_mode": douyinSettings.folderMode,
            "name_format": douyinSettings.nameFormat,
            "desc_length": douyinSettings.descLength,
            "name_length": douyinSettings.nameLength,
            "date_format": douyinSettings.dateFormat,
            "split": douyinSettings.split,
            "storage_format": douyinSettings.storageFormat,
            "max_size": douyinSettings.maxSize,
            "cookie": douyinSettings.cookie,
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

    func cancelTask(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }),
              tasks[index].state == .queued || tasks[index].state == .downloading
        else { return }
        tasks[index].state = .cancelled
        tasks[index].progress = nil
        tasks[index].failureKind = .cancelled
        tasks[index].detail = "已取消"
        Task {
            await BridgeClient.cancel(requestID: id)
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

    private func markTaskStarted(_ id: UUID, platform: DownloadPlatform) -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == id }),
              tasks[index].state == .queued
        else { return false }
        tasks[index].state = .downloading
        tasks[index].progress = nil
        tasks[index].failureKind = nil
        tasks[index].bytesWritten = 0
        tasks[index].fileCount = 0
        tasks[index].detail = "正在调用 \(platform.displayName) 下载引擎…"
        return true
    }

    private func applyProgress(_ event: BridgeProgressEvent, to id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }),
              tasks[index].state == .downloading
        else { return }

        if let progress = event.progress {
            tasks[index].progress = min(max(progress, 0), 0.99)
        }
        if let bytesWritten = event.bytesWritten {
            tasks[index].bytesWritten = max(0, bytesWritten)
        }
        if let fileCount = event.fileCount {
            tasks[index].fileCount = max(0, fileCount)
        }

        var parts = [event.message]
        if tasks[index].bytesWritten > 0 {
            parts.append(
                "已写入 " + ByteCountFormatter.string(
                    fromByteCount: tasks[index].bytesWritten,
                    countStyle: .file
                )
            )
        }
        if tasks[index].fileCount > 0 {
            parts.append("\(tasks[index].fileCount) 个文件")
        }
        tasks[index].detail = parts.joined(separator: " · ")
    }

    private func applyDownloadResult(_ result: DownloadExecutionResult) {
        guard let index = tasks.firstIndex(where: { $0.id == result.prepared.taskID }) else { return }
        if tasks[index].state == .cancelled { return }

        if let response = result.response {
            lastDetails = response.details ?? [:]
            if response.ok {
                tasks[index].state = .completed
                tasks[index].progress = 1.0
                tasks[index].failureKind = nil
                if let bytes = Int64(response.details?["verified_bytes"] ?? "") {
                    tasks[index].bytesWritten = max(tasks[index].bytesWritten, bytes)
                }
                if let files = Int(response.details?["verified_files"] ?? "") {
                    tasks[index].fileCount = max(tasks[index].fileCount, files)
                }
                switch response.details?["verification"] {
                case "existing":
                    tasks[index].detail = "文件已存在，校验通过"
                case "written":
                    let count = tasks[index].fileCount
                    tasks[index].detail = count > 0
                        ? "下载完成，已验证 \(count) 个文件"
                        : "下载完成，文件校验通过"
                default:
                    tasks[index].detail = "下载完成"
                }
            } else {
                let kind = DownloadFailureKind(
                    rawValue: response.details?["error_kind"] ?? ""
                ) ?? inferFailureKind(response.message)
                tasks[index].state = kind == .cancelled ? .cancelled : .failed
                tasks[index].progress = nil
                tasks[index].failureKind = kind
                tasks[index].detail = "\(kind.label)：\(response.message)"
            }
            return
        }

        let kind = result.failureKind ?? .unknown
        tasks[index].state = kind == .cancelled ? .cancelled : .failed
        tasks[index].progress = nil
        tasks[index].failureKind = kind
        tasks[index].detail = "\(kind.label)：\(result.failureMessage ?? kind.label)"
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
        expectedInput: String,
        abortOnInputChange: Bool = true
    ) async -> [LinkValidationResult]? {
        isParsing = true
        defer { isParsing = false }

        var platformChecks: [DownloadPlatform: (ok: Bool, message: String)] = [:]

        for link in links where link.platform != .unknown {
            if platformChecks[link.platform] != nil { continue }

            if abortOnInputChange,
               input.trimmingCharacters(in: .whitespacesAndNewlines) != expectedInput {
                return nil
            }

            do {
                let response = try await sendBridge(.init(command: "validate", url: link.url))
                if abortOnInputChange,
                   input.trimmingCharacters(in: .whitespacesAndNewlines) != expectedInput {
                    return nil
                }

                platformChecks[link.platform] = (response.ok, response.message)
                if input.trimmingCharacters(in: .whitespacesAndNewlines) == expectedInput {
                    lastDetails = response.details ?? [:]
                }
            } catch {
                if abortOnInputChange,
                   input.trimmingCharacters(in: .whitespacesAndNewlines) != expectedInput {
                    return nil
                }

                platformChecks[link.platform] = (false, error.localizedDescription)
                if input.trimmingCharacters(in: .whitespacesAndNewlines) == expectedInput {
                    lastDetails = [:]
                }
            }
        }

        return links.map { link in
            guard link.platform != .unknown else {
                return LinkValidationResult(
                    link: link,
                    ok: false,
                    message: "不支持此链接平台。"
                )
            }
            let check = platformChecks[link.platform]
            return LinkValidationResult(
                link: link,
                ok: check?.ok == true,
                message: check?.message ?? "下载环境检查失败。"
            )
        }
    }

    private func downloadOutputContext(for destination: String) -> DownloadOutputContext? {
        let expanded = NSString(string: destination).expandingTildeInPath
        let target = URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
        let folderName = target.lastPathComponent
        guard !folderName.isEmpty, folderName != "/" else { return nil }
        return DownloadOutputContext(
            bridgeDirectory: target.deletingLastPathComponent().path,
            folderName: folderName
        )
    }

    private func prepareDownloadFolders(
        platforms: Set<DownloadPlatform>,
        folderName: String
    ) async -> [DownloadPlatform: String] {
        var failures: [DownloadPlatform: String] = [:]
        guard JSONSerialization.isValidJSONObject(["folder_name": folderName]),
              let data = try? JSONSerialization.data(
                withJSONObject: ["folder_name": folderName],
                options: [.sortedKeys]
              ),
              let json = String(data: data, encoding: .utf8)
        else {
            for platform in platforms {
                failures[platform] = "下载目录名称无法写入引擎配置。"
            }
            return failures
        }

        for platform in platforms {
            let engine: String
            switch platform {
            case .xiaohongshu: engine = "xiaohongshu"
            case .douyin: engine = "douyin"
            case .unknown: continue
            }

            do {
                let response = try await sendBridge(.init(
                    command: "settings_update",
                    engine: engine,
                    settingsJSON: json
                ))
                if !response.ok {
                    failures[platform] = response.message
                }
            } catch {
                failures[platform] = error.localizedDescription
            }
        }
        return failures
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

private func classifyDownloadError(_ error: Error) -> (kind: DownloadFailureKind, message: String) {
    if let bridgeError = error as? BridgeClient.BridgeError {
        switch bridgeError {
        case .timedOut:
            return (.timeout, bridgeError.localizedDescription)
        case .cancelled:
            return (.cancelled, bridgeError.localizedDescription)
        case .processFailed(let message):
            return (inferFailureKind(message), message)
        case .bridgeNotFound, .pythonNotFound, .malformedResponse:
            return (.engine, bridgeError.localizedDescription)
        }
    }
    if error is CancellationError {
        return (.cancelled, "下载任务已取消。")
    }
    return (inferFailureKind(error.localizedDescription), error.localizedDescription)
}

private func inferFailureKind(_ message: String) -> DownloadFailureKind {
    let value = message.lowercased()
    if value.contains("取消") || value.contains("cancel") { return .cancelled }
    if value.contains("超时") || value.contains("timeout") || value.contains("timed out") { return .timeout }
    if value.contains("429") || value.contains("风控") || value.contains("频繁") || value.contains("rate limit") { return .rateLimited }
    if value.contains("cookie") || value.contains("403") || value.contains("401") || value.contains("登录") { return .auth }
    if value.contains("404") || value.contains("不存在") || value.contains("已删除") || value.contains("not found") { return .notFound }
    if value.contains("磁盘") || value.contains("空间不足") || value.contains("permission denied") || value.contains("no space") { return .disk }
    if value.contains("校验") || value.contains("未检测到新增") || value.contains("verification") { return .verification }
    if value.contains("网络") || value.contains("connection") || value.contains("network") || value.contains("ssl") || value.contains("proxy") { return .network }
    return .engine
}
#endif
