#if canImport(SwiftUI)
import AppKit
import SwiftUI
import SYDownloadCore

/// Shared product-shell geometry and reusable business presentation helpers.
/// Native controls keep their system-owned metrics and appearance.
enum DesignSystem {
    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 12
    static let spaceL: CGFloat = 16
    static let spaceXL: CGFloat = 24
    static let space2XL: CGFloat = 32
    static let space3XL: CGFloat = 40

    static let pageInset: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let panelPadding: CGFloat = 16

    static let sidebarWidth: CGFloat = 220
    static let sidebarTitlebarClearance: CGFloat = 32
    static let sidebarBrandHeight: CGFloat = 56
    static let sidebarNavigationHeight: CGFloat = 38
    static let sidebarNavigationHorizontalPadding: CGFloat = 10
    static let sidebarNavigationIconSize: CGFloat = 16

    static let mainSurfaceInsets = EdgeInsets(top: spaceS, leading: 0, bottom: spaceS, trailing: spaceS)
    static let contentRadius: CGFloat = 14
    static let panelRadius: CGFloat = 10
    static let rowRadius: CGFloat = 8
    static let contentMaxWidth: CGFloat = 1_080

    // Content typography follows macOS semantic text styles.
    static let pageTitleFont = Font.title2.weight(.semibold)
    static let sectionTitleFont = Font.headline
    static let bodyFont = Font.body
    static let uiFont = Font.callout
    static let supportingFont = Font.callout
    static let metadataFont = Font.caption

    // Product accent / sidebar colors may remain branded.
    static let blue = Color(red: 0.039, green: 0.518, blue: 1.0)
    static var accent: Color { blue }
    static var accentSecondary: Color { blue }
    static var accentTint: Color { blue.opacity(0.12) }
    static var sidebarAccent: Color { accentTint }
    static var sidebarAccentForeground: Color { blue }
    static var sidebarHover: Color { Color.primary.opacity(0.055) }

    // Content surfaces use macOS semantic colors rather than copied light/dark RGB values.
    static var sidebarBackground: Color { Color(nsColor: .underPageBackgroundColor) }
    static var mainSurfaceBackground: Color { Color(nsColor: .windowBackgroundColor) }
    static var panelBackground: Color { Color(nsColor: .controlBackgroundColor) }
    static var rowBackground: Color { Color.primary.opacity(0.035) }
    static var warmSurface: Color { Color(nsColor: .textBackgroundColor) }
    static var raisedSurface: Color { Color(nsColor: .controlBackgroundColor) }
    static var hairline: Color { Color(nsColor: .separatorColor).opacity(0.52) }
    static var shadow: Color { Color.black.opacity(0.05) }
    static var focusRing: Color { Color(nsColor: .keyboardFocusIndicatorColor) }
    static var success: Color { Color(nsColor: .systemGreen) }
    static var warning: Color { Color(nsColor: .systemOrange) }
    static var destructive: Color { Color(nsColor: .systemRed) }

    static var pageMaxWidth: CGFloat { contentMaxWidth }
    static var contentPadding: CGFloat { pageInset }
    static var cardRadius: CGFloat { panelRadius }
}

extension DownloadPlatform {
    var designColor: Color {
        switch self {
        case .xiaohongshu, .douyin: return DesignSystem.accent
        case .unknown: return .secondary
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
                        .font(.system(size: size * 0.42, weight: .medium))
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
        }
        .font(DesignSystem.supportingFont.weight(selected ? .semibold : .medium))
        .foregroundStyle(selected ? platform.designColor : .secondary)
        .padding(.horizontal, DesignSystem.spaceS)
        .frame(minHeight: 24)
        .background(
            selected ? platform.designColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor),
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
                .font(.caption2.weight(.semibold))
            Text(state.label)
                .font(.caption.weight(.semibold))
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
            VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                Text(label)
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.semibold))
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
                Divider()
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
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(item.tint)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                        Text(item.value)
                            .font(.headline)
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
            .font(.system(size: 14, weight: selected ? .semibold : .medium))
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
        if configuration.isPressed { return DesignSystem.accent.opacity(0.18) }
        if selected { return DesignSystem.sidebarAccent }
        if isHovered { return DesignSystem.sidebarHover }
        return .clear
    }
}
#endif
