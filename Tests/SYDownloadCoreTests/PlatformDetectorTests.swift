import Testing
@testable import SYDownloadCore

@Test func detectsXHS() {
    #expect(PlatformDetector.detect("https://www.xiaohongshu.com/explore/abc") == .xiaohongshu)
    #expect(PlatformDetector.detect("https://xhslink.com/a/b") == .xiaohongshu)
}

@Test func detectsDouyin() {
    #expect(PlatformDetector.detect("https://v.douyin.com/abc") == .douyin)
}

@Test func rejectsTikTok() {
    #expect(PlatformDetector.detect("https://www.tiktok.com/@user/video/1") == .unknown)
}

@Test func rejectsUnknown() {
    #expect(PlatformDetector.detect("https://example.com/video") == .unknown)
    #expect(PlatformDetector.detect("") == .unknown)
}

@Test func extractsMixedLinksInOrderAndDeduplicates() {
    let input = """
    小红书 https://xhslink.com/abc。
    抖音 https://v.douyin.com/xyz/
    重复 https://xhslink.com/abc
    其他 https://example.com/item;
    TikTok https://www.tiktok.com/@user/video/1
    """

    let links = PlatformDetector.extractLinks(input)
    #expect(links.map(\.url) == [
        "https://xhslink.com/abc",
        "https://v.douyin.com/xyz/",
        "https://example.com/item",
        "https://www.tiktok.com/@user/video/1",
    ])
    #expect(links.map(\.platform) == [
        .xiaohongshu,
        .douyin,
        .unknown,
        .unknown,
    ])
}

@Test func detectsFirstSupportedLinkInsteadOfPlatformPriority() {
    let input = "https://v.douyin.com/first/ https://xhslink.com/second"
    #expect(PlatformDetector.detect(input) == .douyin)
}
