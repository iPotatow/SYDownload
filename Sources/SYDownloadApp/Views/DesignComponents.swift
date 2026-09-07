#if canImport(SwiftUI)
import AppKit
import SwiftUI
import SYDownloadCore

/// Shared geometry, typography, and semantic colors for the SYDownload shell.
enum DesignSystem {
    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 12
    static let spaceL: CGFloat = 16
    static let spaceXL: CGFloat = 24
    static let space2XL: CGFloat = 32
    static let space3XL: CGFloat = 40
    static let pageHeaderTop: CGFloat = 36

    static let pageInset: CGFloat = 24
    static let sectionSpacing: CGFloat = 16
    static let panelPadding: CGFloat = 16
    static let sidebarWidth: CGFloat = 220
    static let mainSurfaceInset: CGFloat = 8
    static let panelRadius: CGFloat = 14
    static let rowRadius: CGFloat = 8
    static let controlRadius: CGFloat = 8
    static let contentMaxWidth: CGFloat = 1_080

    static let controlHeight: CGFloat = 36
    static let compactControlHeight: CGFloat = 32
    static let largeControlHeight: CGFloat = 40
    static let sidebarNavigationHeight: CGFloat = 38
    static let sidebarNavigationHorizontalPadding: CGFloat = 10
    static let sidebarNavigationIconSize: CGFloat = 16

    static let pageTitleFont = Font.system(size: 24, weight: .semibold)
    static let sectionTitleFont = Font.system(size: 16, weight: .semibold)
    static let bodyFont = Font.system(size: 14)
    static let uiFont = Font.system(size: 14, weight: .medium)
    static let supportingFont = Font.system(size: 12)
    static let metadataFont = Font.system(size: 11)

    static var accent: Color { Color(nsColor: .controlAccentColor) }
    static var accentTint: Color { accent.opacity(0.10) }
    static var warmSurface: Color { Color.primary.opacity(0.03) }
    static var raisedSurface: Color { Color.primary.opacity(0.05) }
    static var hairline: Color { Color(nsColor: .separatorColor).opacity(0.45) }
    static var shadow: Color { .black.opacity(0.025) }

    static var sidebarBackground: Color { Color(nsColor: .underPageBackgroundColor) }
    static var mainSurfaceBackground: Color { Color(nsColor: .controlBackgroundColor) }
    static var panelBackground: Color { mainSurfaceBackground }
    static var rowBackground: Color { Color(nsColor: .windowBackgroundColor).opacity(0.72) }
    static var sidebarAccent: Color { Color(nsColor: .selectedContentBackgroundColor) }
    static var sidebarAccentForeground: Color { Color(nsColor: .selectedControlTextColor) }
    static var primaryForeground: Color { Color(nsColor: .selectedControlTextColor) }
    static var sidebarHover: Color { Color(nsColor: .controlHighlightColor) }
    static var primaryHover: Color { Color(nsColor: .alternateSelectedControlColor) }
    static var focusRing: Color { Color(nsColor: .keyboardFocusIndicatorColor) }
    static var pressedOverlay: Color { Color(nsColor: .controlHighlightColor) }
    static var success: Color { Color(nsColor: .systemGreen) }
    static var warning: Color { Color(nsColor: .systemOrange) }
    static var destructive: Color { Color(nsColor: .systemRed) }

    /// Compatibility aliases used by feature views.
    static var pageMaxWidth: CGFloat { contentMaxWidth }
    static var contentPadding: CGFloat { pageInset }
    static var cardRadius: CGFloat { panelRadius }
}

extension DownloadPlatform {
    var designColor: Color {
        switch self {
        case .xiaohongshu: return .red
        case .douyin, .tiktok: return DesignSystem.accent
        case .unknown: return .secondary
        }
    }

    var designSymbol: String {
        switch self {
        case .xiaohongshu: return "book.pages.fill"
        case .douyin, .tiktok: return "music.note"
        case .unknown: return "link"
        }
    }
}

struct AppMark: View {
    var size: CGFloat = 54

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(DesignSystem.accent)
            Image(systemName: "arrow.down")
                .font(.system(size: size * 0.40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("SYDownload")
    }
}

struct IconBadge: View {
    let systemImage: String
    var tint: Color = DesignSystem.accent
    var size: CGFloat = 42

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
                .fill(tint.opacity(0.10))
            Image(systemName: systemImage)
                .font(.system(size: size * 0.36, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct PageHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let systemImage: String

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        systemImage: String = "sparkles"
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.spaceM) {
            IconBadge(systemImage: systemImage)

            VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                Text(eyebrow)
                    .font(DesignSystem.metadataFont.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                    .textCase(.uppercase)

                Text(title)
                    .font(DesignSystem.pageTitleFont)
                    .lineLimit(2)

                Text(subtitle)
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 620, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
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
            .shadow(color: DesignSystem.shadow, radius: 8, y: 3)
    }
}

struct PlatformChip: View {
    let platform: DownloadPlatform
    var selected = false

    var body: some View {
        Label(platform.displayName, systemImage: platform.designSymbol)
            .font(DesignSystem.supportingFont.weight(selected ? .semibold : .medium))
            .foregroundStyle(selected ? platform.designColor : .secondary)
            .padding(.horizontal, DesignSystem.spaceS)
            .frame(minHeight: 24)
            .background(
                selected ? platform.designColor.opacity(0.10) : DesignSystem.warmSurface,
                in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
            )
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct PlatformThumbnail: View {
    let platform: DownloadPlatform
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
                .fill(platform.designColor.opacity(0.09))
            Image(systemName: platform.designSymbol)
                .font(.system(size: size * 0.28, weight: .medium))
                .foregroundStyle(platform.designColor)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(platform.displayName)
    }
}

struct StatusPill: View {
    let state: DownloadTaskState

    var body: some View {
        HStack(spacing: DesignSystem.spaceXS) {
            Image(systemName: symbol)
                .font(.caption2.weight(.semibold))
            Text(state.label)
                .font(DesignSystem.supportingFont.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, DesignSystem.spaceS)
        .frame(minHeight: 24)
        .background(color.opacity(0.10), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch state {
        case .queued: return "clock"
        case .downloading: return "arrow.down.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch state {
        case .queued: return .secondary
        case .downloading: return DesignSystem.accent
        case .completed: return DesignSystem.success
        case .failed: return DesignSystem.destructive
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
            IconBadge(systemImage: systemImage, tint: tint, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DesignSystem.supportingFont)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 20, weight: .semibold))
                    .monospacedDigit()
                Text(detail)
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.panelPadding)
        .background(
            DesignSystem.rowBackground,
            in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
        )
    }
}

struct SidebarButtonStyle: ButtonStyle {
    let selected: Bool
    let isFocused: Bool
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.uiFont.weight(selected ? .semibold : .medium))
            .foregroundStyle(selected ? DesignSystem.sidebarAccentForeground : Color.primary)
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
                        .stroke(DesignSystem.focusRing, lineWidth: 3)
                }
            }
            .opacity(isEnabled ? 1 : 0.5)
            .onHover { isHovered = $0 }
    }

    private func background(configuration: Configuration) -> Color {
        if selected { return DesignSystem.sidebarAccent }
        if configuration.isPressed || isHovered { return DesignSystem.sidebarHover }
        return .clear
    }
}

struct DesignCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                DesignSystem.panelBackground,
                in: RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous)
            )
            .shadow(color: DesignSystem.shadow, radius: 8, y: 3)
    }
}

struct PageBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View { content }
}

extension View {
    func designCard() -> some View { modifier(DesignCardModifier()) }
    func designPageBackground() -> some View { modifier(PageBackgroundModifier()) }
}
#endif
