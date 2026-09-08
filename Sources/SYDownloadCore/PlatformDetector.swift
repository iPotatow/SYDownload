import Foundation

public enum DownloadPlatform: String, Codable, Sendable, CaseIterable, Hashable {
    case xiaohongshu
    case douyin
    case unknown

    public var displayName: String {
        switch self {
        case .xiaohongshu: return "小红书"
        case .douyin: return "抖音"
        case .unknown: return "未知平台"
        }
    }
}

public struct DetectedDownloadLink: Hashable, Sendable {
    public let url: String
    public let platform: DownloadPlatform

    public init(url: String, platform: DownloadPlatform) {
        self.url = url
        self.platform = platform
    }
}

public enum PlatformDetector {
    private static let urlRegex = try! NSRegularExpression(
        pattern: #"https?://[^\s<>\"']+"#,
        options: [.caseInsensitive]
    )
    private static let trailingURLPunctuation = CharacterSet(
        charactersIn: ".,，。;；!！、”’》】）)]}"
    )

    public static func detect(_ input: String) -> DownloadPlatform {
        if let supported = extractLinks(input).first(where: { $0.platform != .unknown }) {
            return supported.platform
        }
        return detectPlatform(in: input)
    }

    public static func extractLinks(_ input: String) -> [DetectedDownloadLink] {
        let searchRange = NSRange(input.startIndex..<input.endIndex, in: input)
        var seen = Set<String>()
        var links: [DetectedDownloadLink] = []

        for match in urlRegex.matches(in: input, range: searchRange) {
            guard let range = Range(match.range, in: input) else { continue }
            let candidate = String(input[range])
                .trimmingCharacters(in: trailingURLPunctuation)
            guard !candidate.isEmpty, seen.insert(candidate).inserted else { continue }
            links.append(
                DetectedDownloadLink(
                    url: candidate,
                    platform: detectPlatform(in: candidate)
                )
            )
        }
        return links
    }

    private static func detectPlatform(in input: String) -> DownloadPlatform {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return .unknown }

        if text.contains("xiaohongshu.com") || text.contains("xhslink.com") {
            return .xiaohongshu
        }
        if text.contains("douyin.com") {
            return .douyin
        }
        return .unknown
    }
}
