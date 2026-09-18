#if canImport(SwiftUI)
import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: AppModel
    let focusedSection: FocusState<AppSection?>.Binding

    var body: some View {
        VStack(spacing: 0) {
            brand

            VStack(spacing: CoreSpacing.xs) {
                sidebarButton(.download, title: "下载", systemImage: "arrow.down.circle.fill")
                sidebarButton(.tasks, title: "任务", systemImage: "tray.full.fill")
                sidebarButton(.history, title: "历史记录", systemImage: "clock.arrow.circlepath")

                Divider()
                    .overlay(CoreColor.divider)
                    .padding(.horizontal, CoreSpacing.m)
                    .padding(.vertical, CoreSpacing.s)

                sidebarButton(.photos, title: "照片整理", systemImage: "photo.on.rectangle.angled")

                Divider()
                    .overlay(CoreColor.divider)
                    .padding(.horizontal, CoreSpacing.m)
                    .padding(.vertical, CoreSpacing.s)

                sidebarButton(.settings, title: "设置", systemImage: "slider.horizontal.3")
            }
            .padding(.top, CoreSpacing.s)

            Spacer(minLength: CoreSpacing.xl)
        }
        .padding(.top, SYDownloadLayout.sidebarTitlebarClearance)
        .padding(.horizontal, SYDownloadLayout.sidebarPadding)
        .padding(.bottom, SYDownloadLayout.sidebarPadding)
    }

    private var brand: some View {
        HStack(spacing: CoreSpacing.s) {
            AppMark(size: SYDownloadLayout.sidebarBrandLogoSize)

            Text("SYDownload")
                .coreTypography(CoreTypography.brand)
                .foregroundStyle(CoreColor.textPrimary)

            Spacer(minLength: 0)
        }
        .frame(height: SYDownloadLayout.sidebarBrandHeight)
        .padding(.horizontal, CoreSpacing.s)
    }

    private func sidebarButton(
        _ section: AppSection,
        title: String,
        systemImage: String
    ) -> some View {
        let selected = model.selection == section
        let focused = focusedSection.wrappedValue == section
        let visuallyActive = selected || focused

        return Button {
            model.selection = section
            focusedSection.wrappedValue = section
        } label: {
            HStack(spacing: CoreSpacing.s) {
                Image(systemName: systemImage)
                    .font(.system(size: CoreMetrics.controlIconSize, weight: .medium))
                    .frame(width: CoreMetrics.controlIconSize)
                    .foregroundStyle(visuallyActive ? CoreColor.accent : CoreColor.textSecondary)

                Text(title)
                    .coreTypography(CoreTypography.control)
                    .foregroundStyle(CoreColor.textPrimary)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .focused(focusedSection, equals: section)
        .buttonStyle(
            CoreSidebarButtonStyle(
                isSelected: selected,
                isFocused: focused,
                height: SYDownloadLayout.sidebarNavigationHeight,
                horizontalPadding: SYDownloadLayout.sidebarNavigationHorizontalPadding
            )
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
#endif
