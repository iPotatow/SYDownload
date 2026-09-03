#if canImport(SwiftUI)
import SwiftUI

/// SYDownload-specific alignment and business-layout dimensions.
/// Reusable visual tokens and control surfaces live in CoreUI.
enum RefinementLayout {
    static let settingsTabsWidth: CGFloat = 600
    static let taskFilterWidth: CGFloat = 440
    static let settingsPathFieldWidth: CGFloat = 360
    static let taskProgressMaxWidth: CGFloat = 420
    static let photoDeleteBarClearance: CGFloat = 64

    static let downloadStatusMinHeight: CGFloat = 56

    static let libraryRowHorizontalPadding: CGFloat = 12
    static let libraryRowVerticalPadding: CGFloat = 8
    static let taskStatusColumnWidth: CGFloat = 88
    static let taskFileColumnWidth: CGFloat = 60
    static let taskDateColumnWidth: CGFloat = 120
    static let taskActionColumnWidth: CGFloat = 124
    static let historyActionColumnWidth: CGFloat = 96

    static let photoDateColumnWidth: CGFloat = 104
    static let photoUngroupedColumnWidth: CGFloat = 160
    static let photoCoverWidth: CGFloat = 112
    static let photoCoverHeight: CGFloat = 96
    static let photoSecondaryThumbnailSize: CGFloat = 44
    static let photoPreviewSpacing: CGFloat = 8
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

/// SYDownload preference row: label stays leading while the value/control column
/// remains anchored to the trailing edge of the settings panel.
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
        CoreSettingsRow(showsDivider: showsDivider) {
            HStack(alignment: .center, spacing: CoreSpacing.l) {
                Text(title)
                    .coreTypography(CoreTypography.body)
                    .foregroundStyle(CoreColor.textPrimary)

                Spacer(minLength: CoreSpacing.l)

                control
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
#endif
