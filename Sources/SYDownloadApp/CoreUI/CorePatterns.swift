#if canImport(SwiftUI)
import SwiftUI

extension View {
    func coreContentSurfaceShadow() -> some View {
        background {
            RoundedRectangle(cornerRadius: CoreRadius.content, style: .continuous)
                .fill(Color.black.opacity(0.10))
                .blur(radius: 3)
                .offset(y: 1)
        }
        .background {
            RoundedRectangle(cornerRadius: CoreRadius.content, style: .continuous)
                .fill(Color.black.opacity(0.10))
                .padding(1)
                .blur(radius: 2)
                .offset(y: 1)
        }
    }
}

struct CorePanel<Content: View>: View {
    let padding: CGFloat
    private let content: Content

    init(padding: CGFloat = CoreMetrics.panelPadding, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                CoreColor.panelBackground,
                in: RoundedRectangle(cornerRadius: CoreRadius.panel, style: .continuous)
            )
    }
}

struct CorePageHeader<Accessory: View>: View {
    let title: String
    private let accessory: Accessory

    init(title: String, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: CoreMetrics.pageHeaderTitleActionGap) {
            Text(title)
                .coreTypography(CoreTypography.pageTitle)
                .foregroundStyle(CoreColor.textPrimary)
                .lineLimit(1)

            Spacer(minLength: CoreMetrics.pageHeaderTitleActionGap)

            accessory
                .font(CoreTypography.controlFont)
                .frame(minHeight: CoreMetrics.controlHeightCompact)
        }
        .padding(.horizontal, CoreMetrics.pageHeaderPaddingX)
        .padding(.top, CoreMetrics.pageHeaderPaddingTop)
        .padding(.bottom, CoreMetrics.pageHeaderPaddingBottom)
    }
}

extension CorePageHeader where Accessory == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

struct CorePageContainer<Actions: View, Content: View>: View {
    let title: String
    let maxWidth: CGFloat
    private let actions: Actions
    private let content: Content

    init(
        title: String,
        maxWidth: CGFloat,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.maxWidth = maxWidth
        self.actions = actions()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            CorePageHeader(title: title) {
                actions
            }

            content
                .padding(.horizontal, CoreSpacing.l)
                .padding(.bottom, CoreSpacing.l)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: maxWidth, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

extension CorePageContainer where Actions == EmptyView {
    init(
        title: String,
        maxWidth: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, maxWidth: maxWidth, actions: { EmptyView() }, content: content)
    }
}

struct CoreStatusPill: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label {
            Text(text)
                .coreTypography(CoreTypography.groupLabel)
                .foregroundStyle(CoreColor.textPrimary)
        } icon: {
            Image(systemName: systemImage)
                .font(CoreTypography.groupLabelFont)
                .foregroundStyle(color)
        }
        .padding(.horizontal, CoreSpacing.m)
        .frame(height: CoreMetrics.controlHeightCompact)
        .background(color.opacity(0.10), in: Capsule())
    }
}

struct CoreDivider: View {
    var body: some View {
        Rectangle()
            .fill(CoreColor.divider)
            .frame(height: CoreMetrics.dividerWidth)
            .accessibilityHidden(true)
    }
}

struct CoreSettingsSection<Content: View>: View {
    let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.s) {
            Text(title)
                .coreTypography(CoreTypography.sectionTitle)
                .foregroundStyle(CoreColor.textPrimary)

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CoreMetrics.panelPadding)
            .background(
                CoreColor.panelBackground,
                in: RoundedRectangle(cornerRadius: CoreRadius.panel, style: .continuous)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CoreSettingsRow<Content: View>: View {
    var showsDivider = true
    private let content: Content

    init(showsDivider: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsDivider = showsDivider
        self.content = content()
    }

    var body: some View {
        content
            .frame(minHeight: CoreMetrics.settingsRowMinHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                if showsDivider {
                    CoreDivider()
                }
            }
    }
}
#endif
