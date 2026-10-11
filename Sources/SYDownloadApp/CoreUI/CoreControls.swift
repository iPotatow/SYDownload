#if canImport(SwiftUI)
import SwiftUI

/// Native button rendering keeps keyboard focus, pressed and disabled feedback.
/// All page actions share the same type and control size; emphasis carries meaning.
enum CoreActionEmphasis { case primary, secondary, tertiary }

private struct CoreActionModifier: ViewModifier {
    let emphasis: CoreActionEmphasis

    @ViewBuilder func body(content: Content) -> some View {
        switch emphasis {
        case .primary: content.buttonStyle(.borderedProminent).modifier(CoreActionMetrics())
        case .secondary: content.buttonStyle(.bordered).modifier(CoreActionMetrics())
        case .tertiary: content.buttonStyle(.borderless).modifier(CoreActionMetrics())
        }
    }
}

private struct CoreActionMetrics: ViewModifier {
    func body(content: Content) -> some View {
        content.font(CoreTypography.controlFont)
            .controlSize(.large)
            .fixedSize(horizontal: true, vertical: false)
            .frame(minHeight: 32)
    }
}

private struct CoreIconControlModifier: ViewModifier {
    @State private var hovered = false
    @Environment(\.isEnabled) private var enabled

    func body(content: Content) -> some View {
        content.labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .font(.system(size: 14))
            .tint(CoreColor.textSecondary)
            .frame(width: 28, height: 28)
            .background(hovered && enabled ? CoreColor.controlHoverBackground : .clear,
                        in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onHover { hovered = $0 }
    }
}

extension View {
    func coreAction(_ emphasis: CoreActionEmphasis = .secondary) -> some View {
        modifier(CoreActionModifier(emphasis: emphasis))
    }

    func coreIconControl() -> some View {
        modifier(CoreIconControlModifier())
    }

    // Icon-only menus already communicate their affordance through the ellipsis.
    func coreIconMenu() -> some View {
        menuStyle(.borderlessButton).menuIndicator(.hidden).coreIconControl()
    }
}

struct CoreSidebarButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isFocused: Bool
    var height: CGFloat = CoreMetrics.controlHeightDefault
    var horizontalPadding: CGFloat = CoreSpacing.m
    var cornerRadius: CGFloat = CoreRadius.row

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                    ? CoreColor.selectionBackground
                    : (isFocused ? CoreColor.controlHoverBackground : Color.clear),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(stateOverlay(isPressed: configuration.isPressed))
            }
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(CoreColor.accent.opacity(0.45), lineWidth: CoreMetrics.borderWidth)
                }
            }
            .opacity(isEnabled ? 1 : CoreState.disabledOpacity)
            .animation(reduceMotion ? nil : CoreMotion.fast, value: configuration.isPressed)
            .animation(reduceMotion ? nil : CoreMotion.fast, value: isHovered)
            .animation(reduceMotion ? nil : CoreMotion.fast, value: isFocused)
            .onHover { isHovered = $0 }
    }

    private func stateOverlay(isPressed: Bool) -> Color {
        if isPressed { return CoreColor.pressedOverlay }
        if isHovered && !isSelected { return CoreColor.hoverOverlay }
        return .clear
    }
}

struct CoreFilterChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
                    .coreTypography(CoreTypography.groupLabel)
                    .foregroundStyle(CoreColor.textPrimary)
            } icon: {
                RemixIcon(systemName: systemImage, size: 12)
                    .foregroundStyle(isSelected ? CoreColor.accent : CoreColor.textSecondary)
            }
            .padding(.horizontal, CoreSpacing.m)
            .frame(height: CoreMetrics.controlHeightCompact)
            .background(
                isSelected ? CoreColor.selectionBackground : CoreColor.controlBackground,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(isSelected ? CoreColor.accent : CoreColor.border, lineWidth: CoreMetrics.borderWidth)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct CoreBadge: View {
    let text: String
    let color: Color
    var systemImage: String? = "circle.fill"

    var body: some View {
        HStack(spacing: CoreSpacing.xs) {
            if let systemImage {
                RemixIcon(systemName: systemImage, size: CoreSpacing.xs)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
            }

            Text(text)
                .coreTypography(CoreTypography.groupLabel)
                .foregroundStyle(CoreColor.textPrimary)
        }
        .padding(.horizontal, CoreSpacing.s)
        .padding(.vertical, CoreSpacing.xs)
        .background(color.opacity(0.10), in: Capsule())
    }
}

struct CoreEmptyStateView: View {
    let title: String
    let systemImage: String
    var description: String? = nil
    var showsProgress = false
    var maxTextWidth: CGFloat? = nil
    var padding: CGFloat = CoreSpacing.l

    var body: some View {
        VStack(spacing: CoreSpacing.s) {
            if showsProgress {
                ProgressView()
                    .controlSize(.regular)
            } else {
                RemixIcon(systemName: systemImage, size: 24)
                    .foregroundStyle(CoreColor.textSecondary)
                    .accessibilityHidden(true)
            }

            Text(title)
                .coreTypography(CoreTypography.control)
                .foregroundStyle(CoreColor.textPrimary)

            if let description, !description.isEmpty {
                Text(description)
                    .coreTypography(CoreTypography.caption)
                    .foregroundStyle(CoreColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: maxTextWidth)
            }
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct CoreSectionHeader: View {
    let title: String
    var description: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xs) {
            Text(title)
                .coreTypography(CoreTypography.sectionTitle)
                .foregroundStyle(CoreColor.textPrimary)
            if let description {
                CoreSupportingText(description)
            }
        }
    }
}

struct CoreSettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .coreTypography(CoreTypography.groupLabel)
            .foregroundStyle(CoreColor.textSecondary)
    }
}

struct CoreSupportingText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .coreTypography(CoreTypography.caption)
            .foregroundStyle(CoreColor.textSecondary)
    }
}

private struct CoreInputSurfaceModifier: ViewModifier {
    let isFocused: Bool
    let isError: Bool

    func body(content: Content) -> some View {
        content
            .background(
                CoreColor.controlBackground,
                in: RoundedRectangle(cornerRadius: CoreRadius.row, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CoreRadius.row, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: CoreMetrics.borderWidth)
            }
    }

    private var borderColor: Color {
        if isError { return CoreColor.danger }
        if isFocused { return CoreColor.accent }
        return CoreColor.border
    }
}

extension View {
    func coreInputSurface(isFocused: Bool = false, isError: Bool = false) -> some View {
        modifier(CoreInputSurfaceModifier(isFocused: isFocused, isError: isError))
    }
}
#endif
