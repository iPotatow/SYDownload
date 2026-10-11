#if canImport(SwiftUI)
import SwiftUI

/// SYDownload-only product geometry.
/// Reusable visual tokens and interaction patterns belong to CoreUI.
enum SYDownloadLayout {
    static let windowWidth: CGFloat = 960
    static let windowHeight: CGFloat = 680

    static let sidebarWidth: CGFloat = 196
    static let sidebarPadding = CoreSpacing.s
    static let sidebarTitlebarClearance = CoreSpacing.xxl
    static let sidebarBrandHeight: CGFloat = 56
    static let sidebarBrandLogoSize: CGFloat = 40
    static let sidebarNavigationHeight: CGFloat = 32
    static let sidebarNavigationHorizontalPadding: CGFloat = 10

    // Hard constraint: top / right / bottom / left = 8 / 8 / 8 / 0.
    static let contentSurfaceInsets = EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 8)

    static let contentMaxWidth: CGFloat = 1_080
    static let pageHeaderSearchWidth: CGFloat = 224

    // Product-specific business layout.
    static let downloadComposerHeight: CGFloat = 160
    static let photoThumbnailSize: CGFloat = 68
    static let settingsFieldWidth: CGFloat = 240
}
#endif
