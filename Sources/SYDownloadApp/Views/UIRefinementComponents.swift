#if canImport(SwiftUI)
import SwiftUI

/// Page-level alignment helpers used by the desktop refinement pass.
/// Core v5 geometry remains defined by `DesignSystem`; these values only name
/// business-layout widths that were previously implicit in individual views.
enum RefinementLayout {
    static let settingsTabsWidth: CGFloat = 360
    static let taskFilterWidth: CGFloat = 440
    static let settingsPathFieldWidth: CGFloat = 360
    static let taskProgressMaxWidth: CGFloat = 420
    static let photoDeleteBarClearance: CGFloat = 64
}

struct CenteredControl<Content: View>: View {
    let width: CGFloat
    private let content: Content

    init(width: CGFloat, @ViewBuilder content: () -> Content) {
        self.width = width
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            content
                .frame(width: width)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Full-width Settings section. The existing Core v5 section styling is kept,
/// while the panel is prevented from shrinking to the intrinsic width of its content.
struct AlignedSettingsSection<Content: View>: View {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.panelPadding)
            .background(
                DesignSystem.panelBackground,
                in: RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Canonical preference row: label stays on the leading edge, while the value/control
/// column is anchored to the trailing edge of the settings panel.
struct SettingsControlRow<Control: View>: View {
    let title: String
    var showsDivider: Bool
    private let control: Control

    init(
        _ title: String,
        showsDivider: Bool = true,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.showsDivider = showsDivider
        self.control = control()
    }

    var body: some View {
        SettingsRow(showsDivider: showsDivider) {
            HStack(alignment: .center, spacing: DesignSystem.spaceL) {
                Text(title)
                    .syTypography(DesignSystem.typographyBody)
                    .foregroundStyle(DesignSystem.textPrimary)

                Spacer(minLength: DesignSystem.spaceL)

                control
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

private struct SYInputSurfaceModifier: ViewModifier {
    let isFocused: Bool
    let isError: Bool

    func body(content: Content) -> some View {
        content
            .background(
                DesignSystem.controlBackground,
                in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: DesignSystem.borderWidth)
            }
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
                        .stroke(DesignSystem.focusRing, lineWidth: DesignSystem.focusRingWidth)
                        .padding(-DesignSystem.focusRingOffset)
                }
            }
    }

    private var borderColor: Color {
        if isError { return DesignSystem.semanticDanger }
        if isFocused { return DesignSystem.accent }
        return DesignSystem.border
    }
}

extension View {
    func syInputSurface(isFocused: Bool = false, isError: Bool = false) -> some View {
        modifier(SYInputSurfaceModifier(isFocused: isFocused, isError: isError))
    }
}

/// `SYTextStyle` is primarily a Text helper, but status labels combine an icon and
/// title. This overload keeps their font token aligned without duplicating raw sizes.
extension Label where Title == Text, Icon == Image {
    func syTypography(_ style: SYTextStyle) -> some View {
        font(style.font)
    }
}
#endif
