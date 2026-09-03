#if canImport(SwiftUI)
import SwiftUI

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
                (isSelected || isFocused) ? CoreColor.selectionBackground : Color.clear,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(stateOverlay(isPressed: configuration.isPressed))
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
                Image(systemName: systemImage)
                    .font(CoreTypography.groupLabelFont)
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
                Image(systemName: systemImage)
                    .font(.system(size: CoreSpacing.xs))
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
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .medium))
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
