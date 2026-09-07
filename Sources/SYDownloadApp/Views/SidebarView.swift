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
                    .padding(.horizontal, DesignSystem.spaceM)
                    .padding(.vertical, DesignSystem.spaceS)

                sidebarButton(.photos, title: "照片整理", systemImage: "photo.on.rectangle.angled")

                Divider()
                    .padding(.horizontal, DesignSystem.spaceM)
                    .padding(.vertical, DesignSystem.spaceS)

                sidebarButton(.settings, title: "设置", systemImage: "slider.horizontal.3")
            }
            .padding(.horizontal, DesignSystem.spaceS)

            Spacer(minLength: DesignSystem.spaceXL)
            sidebarFooter
        }
        .padding(.top, DesignSystem.sidebarTitlebarClearance)
    }

    private var brand: some View {
        HStack(spacing: DesignSystem.spaceS) {
            AppMark(size: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("SYDownload")
                    .font(.system(size: 15, weight: .semibold))
                Text("媒体下载工作台")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(height: DesignSystem.sidebarBrandHeight)
        .padding(.horizontal, DesignSystem.spaceL)
    }

    private var sidebarFooter: some View {
        HStack(spacing: DesignSystem.spaceS) {
            Circle()
                .fill(DesignSystem.success)
                .frame(width: 7, height: 7)
            Text("两个下载引擎已接入")
                .foregroundStyle(.secondary)
        }
        .font(DesignSystem.metadataFont)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.spaceL)
        .padding(.bottom, DesignSystem.spaceL)
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
                    .font(.system(size: DesignSystem.sidebarNavigationIconSize, weight: .semibold))
                    .frame(width: DesignSystem.sidebarNavigationIconSize)
                    .foregroundStyle(selected ? DesignSystem.sidebarAccentForeground : Color.secondary)

                Text(title)
                    .foregroundStyle(selected ? DesignSystem.sidebarAccentForeground : Color.primary)

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
