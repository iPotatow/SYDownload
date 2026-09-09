#if canImport(SwiftUI)
import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: AppModel
    let focusedSection: FocusState<AppSection?>.Binding

    var body: some View {
        VStack(spacing: 0) {
            brand

            VStack(spacing: DesignSystem.spaceXS) {
                sidebarButton(.download, title: "下载", systemImage: "arrow.down.circle.fill")
                sidebarButton(.tasks, title: "任务", systemImage: "tray.full.fill")
                sidebarButton(.history, title: "历史记录", systemImage: "clock.arrow.circlepath")

                Divider()
                    .overlay(DesignSystem.divider)
                    .padding(.horizontal, DesignSystem.spaceM)
                    .padding(.vertical, DesignSystem.spaceS)

                sidebarButton(.photos, title: "照片整理", systemImage: "photo.on.rectangle.angled")

                Divider()
                    .overlay(DesignSystem.divider)
                    .padding(.horizontal, DesignSystem.spaceM)
                    .padding(.vertical, DesignSystem.spaceS)

                sidebarButton(.settings, title: "设置", systemImage: "slider.horizontal.3")
            }
            .padding(.top, DesignSystem.spaceS)

            Spacer(minLength: DesignSystem.spaceXL)
        }
        .padding(.top, DesignSystem.sidebarTitlebarClearance)
        .padding(.horizontal, DesignSystem.sidebarPadding)
        .padding(.bottom, DesignSystem.sidebarPadding)
    }

    private var brand: some View {
        HStack(spacing: DesignSystem.spaceS) {
            AppMark(size: DesignSystem.sidebarBrandLogoSize)

            Text("SYDownload")
                .syTypography(DesignSystem.typographyBrand)
                .foregroundStyle(DesignSystem.textPrimary)

            Spacer(minLength: 0)
        }
        .frame(height: DesignSystem.sidebarBrandHeight)
        .padding(.horizontal, DesignSystem.spaceS)
    }

    private func sidebarButton(
        _ section: AppSection,
        title: String,
        systemImage: String
    ) -> some View {
        let selected = model.selection == section

        return Button {
            model.selection = section
            focusedSection.wrappedValue = section
        } label: {
            HStack(spacing: DesignSystem.spaceS) {
                Image(systemName: systemImage)
                    .font(.system(size: DesignSystem.sidebarNavigationIconSize, weight: .medium))
                    .frame(width: DesignSystem.sidebarNavigationIconSize)
                    .foregroundStyle(selected ? DesignSystem.accent : DesignSystem.textSecondary)

                Text(title)
                    .syTypography(DesignSystem.typographyControl)
                    .foregroundStyle(DesignSystem.textPrimary)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .focused(focusedSection, equals: section)
        .buttonStyle(
            SidebarButtonStyle(
                selected: selected,
                isFocused: focusedSection.wrappedValue == section
            )
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
#endif
