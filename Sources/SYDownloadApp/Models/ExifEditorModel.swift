#if canImport(SwiftUI)
import Foundation
import Combine

@MainActor
final class ExifEditorModel: ObservableObject {
    @Published var options = ExifProcessingOptions()
    @Published private(set) var folder: URL?
    @Published private(set) var plans: [ExifFilePlan] = []
    @Published var selected: Set<URL> = []
    @Published var active: URL?
    @Published private(set) var outcomes: [URL: ExifFileOutcome] = [:]
    @Published private(set) var busy = false
    @Published private(set) var processing = false
    @Published private(set) var completed = 0
    @Published private(set) var total = 0
    @Published private(set) var status = "选择文件夹，预览将要修改的照片。"
    private var worker: Task<Void, Never>?
    private var generation = UUID()
    private var previewOptions: ExifProcessingOptions?
    private var selectsInitialFiles = true

    var canRun: Bool { !busy && previewOptions == options && readyCount > 0 }
    var resultFolder: URL? {
        guard let success = outcomes.values.compactMap({ outcome -> URL? in
            if case .success(let url) = outcome { return url }
            return nil
        }).first else { return nil }
        return success.deletingLastPathComponent()
    }

    var readyCount: Int { plans.filter { selected.contains($0.id) && $0.issue == nil }.count }
    var activePlan: ExifFilePlan? { plans.first { $0.id == active } }

    func open(_ url: URL) {
        guard !processing else { return }
        guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
            status = "请选择文件夹"; return
        }
        if folder != url {
            plans = []; selected = []; active = nil
            selectsInitialFiles = true
        }
        folder = url
        refresh()
    }

    func refresh() {
        guard let folder, !processing else { return }
        worker?.cancel()
        let token = UUID()
        generation = token
        let snapshot = options
        previewOptions = nil
        busy = true
        outcomes = [:]
        status = "正在读取图片…"
        worker = Task.detached { [weak self] in
            do {
                let plans = try ExifProcessingService.scan(folder: folder, options: snapshot)
                guard !Task.isCancelled else { return }
                await self?.finishScan(plans, options: snapshot, token: token)
            } catch {
                await self?.scanFailed(error.localizedDescription, token: token)
            }
        }
    }

    private func finishScan(_ result: [ExifFilePlan], options: ExifProcessingOptions, token: UUID) {
        guard generation == token else { return }
        plans = result
        let valid = Set(result.filter { $0.issue == nil }.map(\.id))
        selected = selectsInitialFiles ? valid : selected.intersection(valid)
        selectsInitialFiles = false
        previewOptions = options
        if !result.contains(where: { $0.id == active }) { active = result.first?.id }
        busy = false
        status = result.isEmpty ? "未找到 JPG、JPEG 或 PNG 图片（只扫描当前文件夹）。" : "共 \(result.count) 张图片，\(readyCount) 张可处理。"
    }

    private func scanFailed(_ message: String, token: UUID) {
        guard generation == token else { return }
        busy = false; plans = []; selected = []
        status = "读取失败：\(message)"
    }

    func cancel() {
        worker?.cancel()
        if processing { status = "正在取消，当前文件完成校验后停止…" }
        else { generation = UUID(); busy = false; previewOptions = nil; status = "已取消读取，请重新读取预览后处理。" }
    }

    func reportImportFailure(_ message: String) { status = "无法打开文件夹：\(message)" }

    func run() {
        guard let folder, canRun else { return }
        let batch = plans.filter { selected.contains($0.id) && $0.issue == nil }
        let snapshot = options
        let backup = folder.appendingPathComponent("EXIF 备份-\(UUID().uuidString)", isDirectory: true)
        busy = true; processing = true; completed = 0; total = batch.count; outcomes = [:]
        status = "正在处理…"
        worker = Task.detached { [weak self] in
            for plan in batch {
                let outcome: ExifFileOutcome
                do {
                    try Task.checkCancellation()
                    let target = try autoreleasepool { try ExifProcessingService.process(plan, folder: folder, options: snapshot, backupFolder: backup) }
                    outcome = .success(target)
                } catch is CancellationError { outcome = .cancelled }
                catch ExifProcessingError.skipped(let message) { outcome = .skipped(message) }
                catch { outcome = .failure(error.localizedDescription) }
                await self?.record(outcome, for: plan.id)
            }
            await self?.finishBatch()
        }
    }

    private func record(_ outcome: ExifFileOutcome, for url: URL) {
        outcomes[url] = outcome; completed += 1
    }

    private func finishBatch() {
        busy = false; processing = false
        let success = outcomes.values.filter { if case .success = $0 { return true }; return false }.count
        let failed = outcomes.values.filter { if case .failure = $0 { return true }; return false }.count
        status = "处理结束：成功 \(success) 张，失败 \(failed) 张，跳过或取消 \(total - success - failed) 张。"
    }
}
#endif
