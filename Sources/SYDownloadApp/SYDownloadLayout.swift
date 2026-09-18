#if canImport(SwiftUI)
import SwiftUI

/// SYDownload-only product geometry.
/// Reusable visual tokens and interaction patterns belong to CoreUI.
enum SYDownloadLayout {
    static let windowWidth: CGFloat = 960
    static let windowHeight: CGFloat = 680

    static let sidebarWidth: CGFloat = 220
    static let sidebarPadding = CoreSpacing.s
    static let sidebarTitlebarClearance = CoreSpacing.xxl
    static let sidebarBrandHeight: CGFloat = 56
    static let sidebarBrandLogoSize: CGFloat = 40
    static let sidebarNavigationHeight: CGFloat = 38
    static let sidebarNavigationHorizontalPadding: CGFloat = 10

    // Hard constraint: top / right / bottom / left = 8 / 8 / 8 / 0.
    static let contentSurfaceInsets = EdgeInsets(
        top: CoreSpacing.s,
        leading: 0,
        bottom: CoreSpacing.s,
        trailing: CoreSpacing.s
    )

    static let contentMaxWidth: CGFloat = 1_080
    static let pageHeaderSearchWidth: CGFloat = 224

    // Product-specific business layout.
    static let downloadComposerHeight: CGFloat = 160
    static let photoThumbnailSize: CGFloat = 68
    static let settingsFieldWidth: CGFloat = 240
}
#endif
