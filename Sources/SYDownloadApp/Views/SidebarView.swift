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

        return Button {
            model.requestSelection(section)
            if model.selection == section {
                focusedSection.wrappedValue = section
            }
        } label: {
            HStack(spacing: CoreSpacing.s) {
                RemixIcon(systemName: systemImage, size: CoreMetrics.controlIconSize)
                    .frame(width: CoreMetrics.controlIconSize)
                    .foregroundStyle(selected ? CoreColor.accent : CoreColor.textSecondary)

                Text(title)
                    .coreTypography(CoreTypography.control)
                    .foregroundStyle(CoreColor.textPrimary)

                Spacer(minLength: 0)

                if section == .tasks {
                    if model.activeTaskCount > 0 {
                        Text("\(model.activeTaskCount)")
                            .coreTypography(CoreTypography.groupLabel)
                            .monospacedDigit()
                            .foregroundStyle(CoreColor.accent)
                            .padding(.horizontal, CoreSpacing.s)
                            .frame(minHeight: 20)
                            .background(CoreColor.selectionBackground, in: Capsule())
                            .accessibilityLabel("\(model.activeTaskCount) 个进行中任务")
                    } else if model.failedTaskCount > 0 {
                        Text("\(model.failedTaskCount)")
                            .coreTypography(CoreTypography.groupLabel)
                            .monospacedDigit()
                            .foregroundStyle(CoreColor.danger)
                            .padding(.horizontal, CoreSpacing.s)
                            .frame(minHeight: 20)
                            .background(CoreColor.danger.opacity(0.10), in: Capsule())
                            .accessibilityLabel("\(model.failedTaskCount) 个失败任务")
                    }
                }
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
