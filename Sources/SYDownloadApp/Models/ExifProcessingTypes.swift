#if canImport(ImageIO)
import Foundation

enum ExifSecondsSource: String, CaseIterable, Identifiable, Sendable {
    case filename = "文件名中的秒数"
    case suffix = "末尾编号（兼容脚本）"
    var id: Self { self }
}

enum ExifSaveMode: String, CaseIterable, Identifiable, Sendable {
    case copies = "保留原图，输出到新文件夹"
    case replaceWithBackup = "备份原图，再替换"
    var id: Self { self }
}

struct ExifProcessingOptions: Equatable, Sendable {
    var writeDates = true
    var secondsSource: ExifSecondsSource = .filename
    var convertPNG = false
    var jpegQuality = 0.95
    var writeCamera = false
    var make = "Apple"
    var model = "iPhone 15 Pro"
    var saveMode: ExifSaveMode = .copies
}

struct ExifFilePlan: Identifiable, Sendable {
    let source: URL
    let targetName: String
    let timestamp: String?
    let originalDate: String
    let originalCreateDate: String
    let originalModifyDate: String
    let originalCamera: String
    let fileSize: Int
    let modifiedAt: Date?
    let issue: String?
    var id: URL { source }
    var convertsPNG: Bool { source.pathExtension.lowercased() == "png" && targetName.hasSuffix(".jpg") }
}

enum ExifFileOutcome: Sendable {
    case success(URL)
    case skipped(String)
    case failure(String)
    case cancelled

    var label: String {
        switch self {
        case .success: return "已完成"
        case .skipped(let message): return "跳过：\(message)"
        case .failure(let message): return "失败：\(message)"
        case .cancelled: return "已取消"
        }
    }
}

enum ExifProcessingError: LocalizedError {
    case invalid(String)
    case skipped(String)
    var errorDescription: String? {
        switch self { case .invalid(let message), .skipped(let message): return message }
    }
}
#endif
