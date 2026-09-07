import Foundation

public enum DownloadPlatform: String, Codable, Sendable, CaseIterable {
    case xiaohongshu
    case douyin
    case tiktok
    case unknown

    public var displayName: String {
        switch self {
        case .xiaohongshu: return "小红书"
        case .douyin: return "抖音"
        case .tiktok: return "TikTok"
        case .unknown: return "未知平台"
        }
    }
}

public enum PlatformDetector {
    public static func detect(_ input: String) -> DownloadPlatform {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return .unknown }

        if text.contains("xiaohongshu.com") || text.contains("xhslink.com") {
            return .xiaohongshu
        }
        if text.contains("douyin.com") {
            return .douyin
        }
        if text.contains("tiktok.com") {
            return .tiktok
        }
        return .unknown
    }
}
