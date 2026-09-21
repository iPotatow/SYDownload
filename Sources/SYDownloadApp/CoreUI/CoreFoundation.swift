#if canImport(SwiftUI)
import AppKit
import SwiftUI

// MARK: - Typography

struct CoreTextStyle {
    let font: Font
    let tracking: CGFloat
    let lineSpacing: CGFloat

    init(
        size: CGFloat,
        weight: Font.Weight,
        nsWeight: NSFont.Weight,
        lineHeight: CGFloat,
        tracking: CGFloat
    ) {
        font = .system(size: size, weight: weight)
        self.tracking = tracking

        let nsFont = NSFont.systemFont(ofSize: size, weight: nsWeight)
        let defaultLineHeight = NSLayoutManager().defaultLineHeight(for: nsFont)
        lineSpacing = max(0, lineHeight - defaultLineHeight)
    }
}

enum CoreTypography {
    static let pageTitle = CoreTextStyle(size: 24, weight: .semibold, nsWeight: .semibold, lineHeight: 30, tracking: -0.4)
    static let sectionTitle = CoreTextStyle(size: 16, weight: .semibold, nsWeight: .semibold, lineHeight: 22, tracking: -0.1)
    static let body = CoreTextStyle(size: 14, weight: .regular, nsWeight: .regular, lineHeight: 20, tracking: 0)
    static let control = CoreTextStyle(size: 14, weight: .medium, nsWeight: .medium, lineHeight: 18, tracking: 0)
    static let caption = CoreTextStyle(size: 12, weight: .regular, nsWeight: .regular, lineHeight: 16, tracking: 0)
    static let groupLabel = CoreTextStyle(size: 12, weight: .medium, nsWeight: .medium, lineHeight: 16, tracking: 0.2)
    static let brand = CoreTextStyle(size: 16, weight: .semibold, nsWeight: .semibold, lineHeight: 20, tracking: -0.1)

    static let pageTitleFont = pageTitle.font
    static let sectionTitleFont = sectionTitle.font
    static let bodyFont = body.font
    static let controlFont = control.font
    static let captionFont = caption.font
    static let groupLabelFont = groupLabel.font
    static let brandFont = brand.font
}

extension Text {
    func coreTypography(_ style: CoreTextStyle) -> some View {
        font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
    }
}

extension Label where Title == Text {
    func coreTypography(_ style: CoreTextStyle) -> some View {
        font(style.font)
    }
}

// MARK: - Spacing & Geometry

enum CoreSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum CoreRadius {
    static let content: CGFloat = 14
    static let panel: CGFloat = 10
    static let row: CGFloat = 8
}

enum CoreMetrics {
    static let sectionSpacing = CoreSpacing.l
    static let panelPadding = CoreSpacing.l

    static let pageHeaderPaddingX = CoreSpacing.xl
    static let pageHeaderPaddingTop: CGFloat = 36
    static let pageHeaderPaddingBottom = CoreSpacing.l
    static let pageHeaderTitleActionGap = CoreSpacing.l
    static let pageHeaderActionGap = CoreSpacing.s

    static let controlHeightCompact: CGFloat = 28
    static let controlHeightSmall: CGFloat = 32
    static let controlHeightDefault: CGFloat = 36
    static let controlHeightLarge: CGFloat = 40
    static let controlHorizontalPadding: CGFloat = 12
    static let controlIconSize: CGFloat = 16
    static let controlRowMinHeight: CGFloat = 40
    static let settingsRowMinHeight: CGFloat = 44

    static let dividerWidth: CGFloat = 0.5
    static let borderWidth: CGFloat = 1
}

// MARK: - Color

enum CoreColor {
    // SYDownload brand accent: Light #AF52DE / Dark #BF5AF2.
    static let accent = adaptiveColor(light: (175, 82, 222), dark: (191, 90, 242))
    static let onAccent = adaptiveColor(light: (255, 255, 255), dark: (255, 255, 255))

    static let windowBackground = adaptiveColor(light: (244, 244, 245), dark: (28, 28, 30))
    static let sidebarBackground = adaptiveColor(light: (242, 242, 243), dark: (32, 32, 34))
    static let contentBackground = adaptiveColor(light: (255, 255, 255), dark: (36, 36, 38))
    static let panelBackground = adaptiveColor(light: (247, 247, 248), dark: (43, 43, 46))

    static let controlBackground = adaptiveColor(light: (255, 255, 255), dark: (50, 50, 53))
    static let controlHoverBackground = adaptiveColor(light: (243, 243, 244), dark: (58, 58, 61))
    static let controlPressedBackground = adaptiveColor(light: (234, 234, 236), dark: (66, 66, 69))

    static let textPrimary = adaptiveColor(light: (29, 29, 31), dark: (245, 245, 247))
    static let textSecondary = adaptiveColor(light: (110, 110, 115), dark: (174, 174, 178))
    static let textTertiary = adaptiveColor(light: (142, 142, 147), dark: (142, 142, 147))
    static let textDisabled = adaptiveColor(light: (174, 174, 178), dark: (99, 99, 102))

    static let divider = adaptiveColor(light: (220, 220, 224), dark: (58, 58, 60))
    static let border = adaptiveColor(light: (199, 199, 204), dark: (72, 72, 74))

    static let hoverOverlay = adaptiveColor(light: (0, 0, 0), dark: (255, 255, 255), lightAlpha: 0.05, darkAlpha: 0.06)
    static let pressedOverlay = adaptiveColor(light: (0, 0, 0), dark: (255, 255, 255), lightAlpha: 0.09, darkAlpha: 0.10)
    static let selectionBackground = adaptiveColor(light: (175, 82, 222), dark: (191, 90, 242), lightAlpha: 0.14, darkAlpha: 0.20)

    static let success = adaptiveColor(light: (36, 138, 61), dark: (48, 209, 88))
    static let warning = adaptiveColor(light: (255, 149, 0), dark: (255, 159, 10))
    static let danger = adaptiveColor(light: (255, 59, 48), dark: (255, 69, 58))
    static let info = accent

    static let modalOverlay = adaptiveColor(light: (0, 0, 0), dark: (0, 0, 0), lightAlpha: 0.32, darkAlpha: 0.48)

    private static func adaptiveColor(
        light: (Int, Int, Int),
        dark: (Int, Int, Int),
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                let components = isDark ? dark : light
                let alpha = isDark ? darkAlpha : lightAlpha
                return NSColor(
                    srgbRed: CGFloat(components.0) / 255,
                    green: CGFloat(components.1) / 255,
                    blue: CGFloat(components.2) / 255,
                    alpha: alpha
                )
            }
        )
    }
}

// MARK: - State & Motion

enum CoreState {
    static let disabledOpacity: CGFloat = 0.45
    static let secondaryOpacity: CGFloat = 0.72
    static let tertiaryOpacity: CGFloat = 0.55
}

enum CoreMotion {
    static let fast = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.10)
    static let standard = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.16)
    static let slow = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.22)
    static let enter = Animation.timingCurve(0, 0, 0, 1, duration: 0.16)
    static let exit = Animation.timingCurve(0.4, 0, 1, 1, duration: 0.12)
}
#endif
