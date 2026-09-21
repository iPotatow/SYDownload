#if canImport(SwiftUI)
import SwiftUI

/// Compatibility wrapper that keeps existing call sites while rendering
/// Apple's native SF Symbols throughout the app.
struct RemixIcon: View {
    let systemName: String
    var size: CGFloat = CoreMetrics.controlIconSize

    var body: some View {
        Image(systemName: appleSystemName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var appleSystemName: String {
        switch systemName {
        case "settings":
            return "gearshape"
        case "folder.fill.badge.plus":
            return "folder.badge.plus"
        default:
            return systemName
        }
    }
}

extension Label where Title == Text, Icon == RemixIcon {
    init(_ title: String, remixSystemImage: String) {
        self.init {
            Text(title)
        } icon: {
            RemixIcon(systemName: remixSystemImage)
        }
    }
}

extension Button where Label == SwiftUI.Label<Text, RemixIcon> {
    init(
        _ title: String,
        remixSystemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.init(role: role, action: action) {
            Label(title, remixSystemImage: remixSystemImage)
        }
    }
}
#endif
