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
    static let pageHeaderTop: CGFloat = 24
    static let titlebarClearance: CGFloat = 32
    static let pageTitlebarClearance: CGFloat = titlebarClearance
    static let sidebarTitlebarClearance: CGFloat = titlebarClearance

    /// Main content uses the 4px grid. The shell provides its own 8px inset;
    /// pages start with the spec's 16px internal padding.
    static let pageInset: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let panelPadding: CGFloat = 16
    static let sidebarWidth: CGFloat = 220
    static let mainSurfaceInsets = EdgeInsets(
        top: spaceS,
        leading: 0,
        bottom: spaceS,
        trailing: spaceS
    )
    static let sidebarBrandHeight: CGFloat = 56
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

    static let pageTitleFont = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let sectionTitleFont = Font.system(size: 16, weight: .semibold)
    static let bodyFont = Font.system(size: 14)
    static let uiFont = Font.system(size: 14, weight: .medium)
    static let supportingFont = Font.system(size: 12)
    static let metadataFont = Font.system(size: 11)

    // The app uses a quiet cyan/purple signature instead of inheriting the
    // system's often-bright blue accent. Purple is reserved for secondary
    // emphasis so the palette still feels restrained and legible.
    static let cyan = Color(red: 0.08, green: 0.66, blue: 0.70)
    static let purple = Color(red: 0.43, green: 0.34, blue: 0.78)
    static var accent: Color { cyan }
    static var accentSecondary: Color { purple }
    static var accentTint: Color { cyan.opacity(0.11) }
    static var warmSurface: Color { Color.primary.opacity(0.035) }
    static var raisedSurface: Color { Color.primary.opacity(0.06) }
    static var hairline: Color { Color(nsColor: .separatorColor).opacity(0.52) }
    static var shadow: Color { cyan.opacity(0.045) }

    static var sidebarBackground: Color { Color(nsColor: .underPageBackgroundColor) }
    static var mainSurfaceBackground: Color { Color(nsColor: .controlBackgroundColor) }
    static var panelBackground: Color { Color(nsColor: .windowBackgroundColor).opacity(0.88) }
    static var rowBackground: Color { Color.primary.opacity(0.035) }
    static var sidebarAccent: Color { cyan.opacity(0.18) }
    static var sidebarAccentForeground: Color { cyan }
    static var primaryForeground: Color { cyan }
    static var sidebarHover: Color { Color.primary.opacity(0.055) }
    static var primaryHover: Color { cyan.opacity(0.16) }
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
        case .xiaohongshu: return DesignSystem.accentSecondary
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
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
            } else {
                Image(systemName: "arrow.down.circle")
                    .resizable()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(DesignSystem.accent)
                    .padding(size * 0.08)
            }
        }
        .scaledToFit()
        .frame(width: size, height: size)
        .accessibilityLabel("SYDownload")
    }

    /// Avoid Bundle.module here. A signed macOS .app must keep SwiftPM's
    /// resource bundle under Contents/Resources, while the generated
    /// Bundle.module accessor expects it next to Bundle.main.bundleURL and
    /// traps if it is not there. Resolve the packaged icon explicitly and use
    /// the adjacent SwiftPM bundle only for local `swift run` development.
    private var appIcon: NSImage? {
        let fileName = "SYDownloadIcon.png"
        var candidates: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent(fileName))
            candidates.append(
                resourceURL
                    .appendingPathComponent("SYDownload_SYDownloadApp.bundle")
                    .appendingPathComponent(fileName)
            )
        }

        if let executableURL = Bundle.main.executableURL {
            candidates.append(
                executableURL
                    .deletingLastPathComponent()
                    .appendingPathComponent("SYDownload_SYDownloadApp.bundle")
                    .appendingPathComponent(fileName)
            )
        }

        for url in candidates {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
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
            IconBadge(systemImage: systemImage, tint: DesignSystem.accent, size: 40)

            VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                Text(eyebrow)
                    .font(DesignSystem.metadataFont.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.35)

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
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous)
                    .strokeBorder(DesignSystem.hairline, lineWidth: 1)
            }
            .shadow(color: DesignSystem.shadow, radius: 12, y: 4)
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

/// A low-elevation section heading used when a page has several related
/// controls. It deliberately avoids turning every group into a card.
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
                    .font(DesignSystem.sectionTitleFont)
                if let detail {
                    Text(detail)
                        .font(DesignSystem.supportingFont)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            content
        }
    }
}

/// A compact row for document-like lists and settings. Separation supplies
/// hierarchy without the visual weight of another rounded container.
struct InsetRow<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.vertical, DesignSystem.spaceM)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(DesignSystem.hairline)
                    .frame(height: 1)
            }
    }
}

/// A horizontal overview strip for queue and archive totals.
struct MetricStrip: View {
    let items: [(label: String, value: String, detail: String, symbol: String, tint: Color)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Divider().frame(height: 34)
                }
                HStack(spacing: DesignSystem.spaceS) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(item.tint)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.value)
                            .font(.system(size: 18, weight: .semibold))
                            .monospacedDigit()
                        Text(item.label)
                            .font(DesignSystem.metadataFont)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignSystem.spaceM)
            }
        }
        .padding(.vertical, DesignSystem.spaceS)
        .background(DesignSystem.rowBackground, in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous))
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
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous)
                    .strokeBorder(DesignSystem.hairline, lineWidth: 1)
            }
            .shadow(color: DesignSystem.shadow, radius: 12, y: 4)
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
