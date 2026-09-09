#if canImport(SwiftUI)
import AppKit
import SwiftUI
import SYDownloadCore

struct SYTextStyle {
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

/// Shared product-shell geometry and reusable business presentation helpers.
enum DesignSystem {
    // MARK: - Spacing

    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 12
    static let spaceL: CGFloat = 16
    static let space20: CGFloat = 20
    static let spaceXL: CGFloat = 24
    static let space2XL: CGFloat = 32
    static let space3XL: CGFloat = 40

    // MARK: - Window & Layout

    static let windowWidth: CGFloat = 960
    static let windowHeight: CGFloat = 680

    static let contentBodyPadding: CGFloat = 16
    static let pageInset = contentBodyPadding
    static let sectionSpacing: CGFloat = 16
    static let panelPadding: CGFloat = 16

    static let pageHeaderPaddingX: CGFloat = 24
    static let pageHeaderPaddingTop: CGFloat = 36
    static let pageHeaderPaddingBottom: CGFloat = 16
    static let pageHeaderTitleActionGap: CGFloat = 16
    static let pageHeaderActionGap: CGFloat = 8
    static let pageHeaderSearchWidth: CGFloat = 224

    static let sidebarWidth: CGFloat = 220
    static let sidebarPadding: CGFloat = 8
    static let sidebarTitlebarClearance: CGFloat = 32
    static let sidebarBrandHeight: CGFloat = 56
    static let sidebarBrandLogoSize: CGFloat = 40
    static let sidebarNavigationHeight: CGFloat = 38
    static let sidebarNavigationHorizontalPadding: CGFloat = 10
    static let sidebarNavigationIconSize: CGFloat = 16

    static let mainSurfaceInsets = EdgeInsets(top: spaceS, leading: 0, bottom: spaceS, trailing: spaceS)
    static let contentRadius: CGFloat = 14
    static let panelRadius: CGFloat = 10
    static let rowRadius: CGFloat = 8
    static let contentMaxWidth: CGFloat = 1_080

    static let controlHeightCompact: CGFloat = 28
    static let controlHeightSmall: CGFloat = 32
    static let controlHeightDefault: CGFloat = 36
    static let controlHeightLarge: CGFloat = 40
    static let controlHorizontalPadding: CGFloat = 12
    static let controlIconSize: CGFloat = 16

    static let dividerWidth: CGFloat = 0.5
    static let borderWidth: CGFloat = 1
    static let focusRingWidth: CGFloat = 2
    static let focusRingOffset: CGFloat = 2
    static let controlRowMinHeight: CGFloat = 40
    static let settingsRowMinHeight: CGFloat = 44

    /// Named business-component dimensions; all remain on the Core v5 4 px grid.
    static let downloadComposerHeight: CGFloat = 160
    static let photoThumbnailSize: CGFloat = 68
    static let settingsFieldWidth: CGFloat = 240

    // MARK: - Typography

    static let typographyPageTitle = SYTextStyle(
        size: 24,
        weight: .semibold,
        nsWeight: .semibold,
        lineHeight: 30,
        tracking: -0.4
    )
    static let typographySectionTitle = SYTextStyle(
        size: 16,
        weight: .semibold,
        nsWeight: .semibold,
        lineHeight: 22,
        tracking: -0.1
    )
    static let typographyBody = SYTextStyle(
        size: 14,
        weight: .regular,
        nsWeight: .regular,
        lineHeight: 20,
        tracking: 0
    )
    static let typographyControl = SYTextStyle(
        size: 14,
        weight: .medium,
        nsWeight: .medium,
        lineHeight: 18,
        tracking: 0
    )
    static let typographyCaption = SYTextStyle(
        size: 12,
        weight: .regular,
        nsWeight: .regular,
        lineHeight: 16,
        tracking: 0
    )
    static let typographyGroupLabel = SYTextStyle(
        size: 12,
        weight: .medium,
        nsWeight: .medium,
        lineHeight: 16,
        tracking: 0.2
    )
    static let typographyBrand = SYTextStyle(
        size: 16,
        weight: .semibold,
        nsWeight: .semibold,
        lineHeight: 20,
        tracking: -0.1
    )

    // Font-only aliases for controls and symbols that cannot use Text-specific metrics.
    static let pageTitleFont = typographyPageTitle.font
    static let sectionTitleFont = typographySectionTitle.font
    static let bodyFont = typographyBody.font
    static let uiFont = typographyControl.font
    static let supportingFont = typographyCaption.font
    static let metadataFont = typographyCaption.font
    static let groupLabelFont = typographyGroupLabel.font
    static let brandFont = typographyBrand.font

    // MARK: - Colors

    static let accent = adaptiveColor(light: (0, 122, 255), dark: (10, 132, 255))
    static let onAccent = adaptiveColor(light: (255, 255, 255), dark: (255, 255, 255))
    static let windowBackground = adaptiveColor(light: (244, 244, 245), dark: (28, 28, 30))
    static let sidebarBackground = adaptiveColor(light: (242, 242, 243), dark: (32, 32, 34))
    static let mainSurfaceBackground = adaptiveColor(light: (255, 255, 255), dark: (36, 36, 38))
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
    static let hoverOverlay = adaptiveColor(
        light: (0, 0, 0),
        dark: (255, 255, 255),
        lightAlpha: 0.05,
        darkAlpha: 0.06
    )
    static let pressedOverlay = adaptiveColor(
        light: (0, 0, 0),
        dark: (255, 255, 255),
        lightAlpha: 0.09,
        darkAlpha: 0.10
    )
    static let selectionBackground = adaptiveColor(
        light: (0, 122, 255),
        dark: (10, 132, 255),
        lightAlpha: 0.14,
        darkAlpha: 0.20
    )
    static let focusRing = adaptiveColor(
        light: (0, 122, 255),
        dark: (10, 132, 255),
        lightAlpha: 0.35,
        darkAlpha: 0.45
    )

    static let semanticSuccess = adaptiveColor(light: (36, 138, 61), dark: (48, 209, 88))
    static let semanticWarning = adaptiveColor(light: (255, 149, 0), dark: (255, 159, 10))
    static let semanticDanger = adaptiveColor(light: (255, 59, 48), dark: (255, 69, 58))
    static let semanticInfo = accent
    static let modalOverlay = adaptiveColor(
        light: (0, 0, 0),
        dark: (0, 0, 0),
        lightAlpha: 0.32,
        darkAlpha: 0.48
    )

    // Compatibility aliases used across existing feature views.
    static var blue: Color { accent }
    static var accentSecondary: Color { accent }
    static var accentTint: Color { selectionBackground }
    static var sidebarAccent: Color { selectionBackground }
    static var sidebarAccentForeground: Color { accent }
    static var sidebarHover: Color { hoverOverlay }
    static var rowBackground: Color { controlBackground }
    static var warmSurface: Color { panelBackground }
    static var raisedSurface: Color { controlBackground }
    static var hairline: Color { divider }
    static var shadow: Color { Color.black.opacity(0.10) }
    static var success: Color { semanticSuccess }
    static var warning: Color { semanticWarning }
    static var destructive: Color { semanticDanger }

    // MARK: - State & Motion

    static let disabledOpacity: CGFloat = 0.45
    static let secondaryOpacity: CGFloat = 0.72
    static let tertiaryOpacity: CGFloat = 0.55

    static let motionFast = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.10)
    static let motionStandard = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.16)
    static let motionSlow = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.22)
    static let motionEnter = Animation.timingCurve(0, 0, 0, 1, duration: 0.16)
    static let motionExit = Animation.timingCurve(0.4, 0, 1, 1, duration: 0.12)

    static var pageMaxWidth: CGFloat { contentMaxWidth }
    static var contentPadding: CGFloat { contentBodyPadding }
    static var cardRadius: CGFloat { panelRadius }

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

extension Text {
    func syTypography(_ style: SYTextStyle) -> some View {
        font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
    }
}

extension View {
    func syContentSurfaceShadow() -> some View {
        background {
            RoundedRectangle(cornerRadius: DesignSystem.contentRadius, style: .continuous)
                .fill(Color.black.opacity(0.10))
                .blur(radius: 3)
                .offset(y: 1)
        }
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.contentRadius, style: .continuous)
                .fill(Color.black.opacity(0.10))
                .padding(1)
                .blur(radius: 2)
                .offset(y: 1)
        }
    }
}

extension DownloadPlatform {
    var designColor: Color {
        switch self {
        case .xiaohongshu, .douyin: return DesignSystem.accent
        case .unknown: return DesignSystem.textSecondary
        }
    }

    var brandAssetName: String? {
        switch self {
        case .xiaohongshu: return "XiaohongshuPlatformIcon"
        case .douyin: return "DouyinPlatformIcon"
        case .unknown: return nil
        }
    }

    var fallbackSymbol: String {
        switch self {
        case .xiaohongshu: return "book.pages.fill"
        case .douyin: return "music.note"
        case .unknown: return "link"
        }
    }
}

struct AppMark: View {
    var size: CGFloat = 32

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("SYDownload")
    }
}

struct IconBadge: View {
    let systemImage: String
    var tint: Color = DesignSystem.accent
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
                .fill(tint.opacity(0.10))
            Image(systemName: systemImage)
                .font(.system(size: DesignSystem.controlIconSize, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct PageHeader<Actions: View>: View {
    let title: String
    private let actions: Actions

    init(title: String, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.pageHeaderTitleActionGap) {
            Text(title)
                .syTypography(DesignSystem.typographyPageTitle)
                .foregroundStyle(DesignSystem.textPrimary)
                .lineLimit(1)

            Spacer(minLength: DesignSystem.pageHeaderTitleActionGap)

            HStack(spacing: DesignSystem.pageHeaderActionGap) {
                actions
            }
            .font(DesignSystem.uiFont)
        }
        .padding(.horizontal, DesignSystem.pageHeaderPaddingX)
        .padding(.top, DesignSystem.pageHeaderPaddingTop)
        .padding(.bottom, DesignSystem.pageHeaderPaddingBottom)
    }
}

extension PageHeader where Actions == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

struct PageContainer<Actions: View, Content: View>: View {
    let title: String
    private let actions: Actions
    private let content: Content

    init(
        title: String,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.actions = actions()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: title) {
                actions
            }

            content
                .padding(.horizontal, DesignSystem.contentBodyPadding)
                .padding(.bottom, DesignSystem.contentBodyPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: DesignSystem.pageMaxWidth, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

extension PageContainer where Actions == EmptyView {
    init(title: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, actions: { EmptyView() }, content: content)
    }
}

struct SurfaceCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    init(padding: CGFloat = DesignSystem.panelPadding, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                DesignSystem.panelBackground,
                in: RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous)
            )
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceS) {
            Text(title)
                .syTypography(DesignSystem.typographySectionTitle)
                .foregroundStyle(DesignSystem.textPrimary)

            VStack(spacing: 0) {
                content
            }
            .padding(DesignSystem.panelPadding)
            .background(
                DesignSystem.panelBackground,
                in: RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous)
            )
        }
    }
}

struct SettingsRow<Content: View>: View {
    var showsDivider = true
    private let content: Content

    init(showsDivider: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsDivider = showsDivider
        self.content = content()
    }

    var body: some View {
        content
            .frame(minHeight: DesignSystem.settingsRowMinHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                if showsDivider {
                    Rectangle()
                        .fill(DesignSystem.divider)
                        .frame(height: DesignSystem.dividerWidth)
                }
            }
    }
}

struct PlatformBrandIcon: View {
    let platform: DownloadPlatform
    var size: CGFloat
    var cornerRadius: CGFloat

    var body: some View {
        Group {
            if let image = brandImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(platform.designColor.opacity(0.09))
                    Image(systemName: platform.fallbackSymbol)
                        .font(DesignSystem.uiFont)
                        .foregroundStyle(platform.designColor)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private var brandImage: NSImage? {
        guard let assetName = platform.brandAssetName,
              let url = Bundle.module.url(forResource: assetName, withExtension: "jpg")
        else { return nil }
        return NSImage(contentsOf: url)
    }
}

struct PlatformChip: View {
    let platform: DownloadPlatform
    var selected = false

    var body: some View {
        HStack(spacing: DesignSystem.spaceXS) {
            PlatformBrandIcon(platform: platform, size: 16, cornerRadius: 4)
            Text(platform.displayName)
                .syTypography(DesignSystem.typographyGroupLabel)
        }
        .foregroundStyle(selected ? platform.designColor : DesignSystem.textSecondary)
        .padding(.horizontal, DesignSystem.spaceS)
        .frame(minHeight: DesignSystem.spaceXL)
        .background(
            selected ? DesignSystem.selectionBackground : DesignSystem.controlBackground,
            in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct PlatformThumbnail: View {
    let platform: DownloadPlatform
    var size: CGFloat = 56

    var body: some View {
        PlatformBrandIcon(
            platform: platform,
            size: size,
            cornerRadius: DesignSystem.rowRadius
        )
        .accessibilityLabel(platform.displayName)
    }
}

struct StatusPill: View {
    let state: DownloadTaskState

    var body: some View {
        HStack(spacing: DesignSystem.spaceXS) {
            Image(systemName: symbol)
                .font(DesignSystem.groupLabelFont)
            Text(state.label)
                .syTypography(DesignSystem.typographyGroupLabel)
        }
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch state {
        case .queued: return "clock"
        case .downloading: return "arrow.down.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    private var color: Color {
        switch state {
        case .queued: return DesignSystem.textSecondary
        case .downloading: return DesignSystem.accent
        case .completed: return DesignSystem.semanticSuccess
        case .failed: return DesignSystem.semanticDanger
        case .cancelled: return DesignSystem.textSecondary
        }
    }
}

struct MetricCard: View {
    let label: String
    let value: String
    let detail: String
    let systemImage: String
    var tint: Color = DesignSystem.accent

    var body: some View {
        HStack(spacing: DesignSystem.spaceM) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                Text(label)
                    .syTypography(DesignSystem.typographyCaption)
                    .foregroundStyle(DesignSystem.textSecondary)
                Text(value)
                    .syTypography(DesignSystem.typographySectionTitle)
                    .foregroundStyle(DesignSystem.textPrimary)
                    .monospacedDigit()
                Text(detail)
                    .syTypography(DesignSystem.typographyCaption)
                    .foregroundStyle(DesignSystem.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.panelPadding)
    }
}

struct SectionGroup<Content: View>: View {
    let title: String
    let detail: String?
    private let content: Content

    init(_ title: String, detail: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceS) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.spaceS) {
                Text(title)
                    .syTypography(DesignSystem.typographySectionTitle)
                    .foregroundStyle(DesignSystem.textPrimary)
                if let detail {
                    Text(detail)
                        .syTypography(DesignSystem.typographyCaption)
                        .foregroundStyle(DesignSystem.textSecondary)
                }
                Spacer(minLength: 0)
            }
            content
        }
    }
}

struct InsetRow<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.vertical, DesignSystem.spaceM)
            .frame(minHeight: DesignSystem.controlRowMinHeight)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(DesignSystem.divider)
                    .frame(height: DesignSystem.dividerWidth)
            }
    }
}

struct MetricStrip: View {
    let items: [(label: String, value: String, detail: String, symbol: String, tint: Color)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(DesignSystem.divider)
                        .frame(width: DesignSystem.dividerWidth, height: DesignSystem.space2XL)
                }
                HStack(spacing: DesignSystem.spaceS) {
                    Image(systemName: item.symbol)
                        .font(DesignSystem.uiFont)
                        .foregroundStyle(item.tint)
                        .frame(width: DesignSystem.spaceXL)
                    VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                        Text(item.value)
                            .syTypography(DesignSystem.typographySectionTitle)
                            .foregroundStyle(DesignSystem.textPrimary)
                            .monospacedDigit()
                        Text(item.label)
                            .syTypography(DesignSystem.typographyCaption)
                            .foregroundStyle(DesignSystem.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignSystem.spaceM)
            }
        }
        .padding(.vertical, DesignSystem.spaceS)
    }
}

struct SidebarButtonStyle: ButtonStyle {
    let selected: Bool
    let isFocused: Bool

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.uiFont)
            .foregroundStyle(DesignSystem.textPrimary)
            .padding(.horizontal, DesignSystem.sidebarNavigationHorizontalPadding)
            .frame(height: DesignSystem.sidebarNavigationHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                background(configuration: configuration),
                in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
            )
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
                        .stroke(DesignSystem.focusRing, lineWidth: DesignSystem.focusRingWidth)
                        .padding(-DesignSystem.focusRingOffset)
                }
            }
            .opacity(isEnabled ? 1 : DesignSystem.disabledOpacity)
            .animation(reduceMotion ? nil : DesignSystem.motionFast, value: configuration.isPressed)
            .animation(reduceMotion ? nil : DesignSystem.motionFast, value: isHovered)
            .animation(reduceMotion ? nil : DesignSystem.motionFast, value: isFocused)
            .onHover { isHovered = $0 }
    }

    private func background(configuration: Configuration) -> Color {
        if configuration.isPressed { return DesignSystem.pressedOverlay }
        if selected { return DesignSystem.selectionBackground }
        if isHovered { return DesignSystem.hoverOverlay }
        return .clear
    }
}
#endif
