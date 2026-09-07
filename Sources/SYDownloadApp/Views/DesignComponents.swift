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
    static let pageHeaderTop: CGFloat = 16
    static let titlebarClearance: CGFloat = 32
    static let pageTitlebarClearance: CGFloat = 0
    static let sidebarTitlebarClearance: CGFloat = titlebarClearance

    static let pageInset: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let panelPadding: CGFloat = 16
    static let sidebarWidth: CGFloat = 220
    static let mainSurfaceInsets = EdgeInsets(top: spaceS, leading: 0, bottom: spaceS, trailing: spaceS)
    static let sidebarBrandHeight: CGFloat = 56
    static let panelRadius: CGFloat = 10
    static let contentRadius: CGFloat = 14
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

    static let blue = Color(red: 0.039, green: 0.518, blue: 1.0)
    static var accent: Color { blue }
    static var accentSecondary: Color { blue }
    static var accentTint: Color { semantic(light: "#0A84FF", dark: "#0A84FF", lightOpacity: 0.12, darkOpacity: 0.22) }
    static var warmSurface: Color { Color.primary.opacity(0.035) }
    static var raisedSurface: Color { Color.primary.opacity(0.06) }
    static var hairline: Color { Color(nsColor: .separatorColor).opacity(0.52) }
    static var shadow: Color { Color.black.opacity(0.05) }

    static var sidebarBackground: Color { semantic(light: "#EAEAEE", dark: "#2C2C2E") }
    static var mainSurfaceBackground: Color { semantic(light: "#FFFFFF", dark: "#1C1C1E") }
    static var panelBackground: Color { semantic(light: "#FFFFFF", dark: "#2C2C2E") }
    static var rowBackground: Color { Color.primary.opacity(0.035) }
    static var sidebarAccent: Color { accentTint }
    static var sidebarAccentForeground: Color { blue }
    static var primaryForeground: Color { blue }
    static var sidebarHover: Color { Color.primary.opacity(0.055) }
    static var primaryHover: Color { semantic(light: "#0A84FF", dark: "#0A84FF", lightOpacity: 0.16, darkOpacity: 0.22) }
    static var focusRing: Color { Color(nsColor: .keyboardFocusIndicatorColor) }
    static var pressedOverlay: Color { Color(nsColor: .controlHighlightColor) }
    static var success: Color { Color(nsColor: .systemGreen) }
    static var warning: Color { Color(nsColor: .systemOrange) }
    static var destructive: Color { Color(nsColor: .systemRed) }

    private static func semantic(light: String, dark: String, lightOpacity: CGFloat = 1, darkOpacity: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let color = NSColor(hex: isDark ? dark : light)
            return color.withAlphaComponent(isDark ? darkOpacity : lightOpacity)
        } ?? NSColor(hex: light))
    }

    static var pageMaxWidth: CGFloat { contentMaxWidth }
    static var contentPadding: CGFloat { pageInset }
    static var cardRadius: CGFloat { panelRadius }
}

extension DownloadPlatform {
    var designColor: Color {
        switch self {
        case .xiaohongshu: return DesignSystem.accent
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

/// Compact desktop page header. The legacy eyebrow and icon parameters are
/// retained at the call site for source compatibility, but visual hierarchy is
/// intentionally carried by title, subtitle, spacing and weight rather than a
/// marketing-style hero block.
struct PageHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let systemImage: String

    init(
        eyebrow: String = "",
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
        VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
            Text(title)
                .font(DesignSystem.pageTitleFont)
                .lineLimit(2)

            if !subtitle.isEmpty {
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
            Image(systemName: systemImage)
                .foregroundStyle(tint)
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
    }
}

struct SidebarButtonStyle: ButtonStyle {
    let selected: Bool
    let isFocused: Bool
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

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
                        .stroke(DesignSystem.focusRing, lineWidth: contrast == .increased ? 3 : 2)
                }
            }
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .onHover { isHovered = $0 }
    }

    private func background(configuration: Configuration) -> Color {
        if selected { return DesignSystem.sidebarAccent }
        if configuration.isPressed || isHovered { return DesignSystem.sidebarHover }
        return .clear
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let number = UInt64(value, radix: 16) ?? 0
        self.init(
            calibratedRed: CGFloat((number >> 16) & 0xff) / 255,
            green: CGFloat((number >> 8) & 0xff) / 255,
            blue: CGFloat(number & 0xff) / 255,
            alpha: 1
        )
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
