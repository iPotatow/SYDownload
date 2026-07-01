import Testing
@testable import XDownloaderCore

@Test func detectsXHS() {
    #expect(PlatformDetector.detect("https://www.xiaohongshu.com/explore/abc") == .xiaohongshu)
    #expect(PlatformDetector.detect("https://xhslink.com/a/b") == .xiaohongshu)
}

@Test func detectsDouyin() {
    #expect(PlatformDetector.detect("https://v.douyin.com/abc") == .douyin)
}

@Test func detectsTikTok() {
    #expect(PlatformDetector.detect("https://www.tiktok.com/@user/video/1") == .tiktok)
}

@Test func rejectsUnknown() {
    #expect(PlatformDetector.detect("https://example.com/video") == .unknown)
    #expect(PlatformDetector.detect("") == .unknown)
}
