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

            Spacer(minLength: DesignSystem.spaceXL)
            sidebarFooter
        }
        .padding(.top, DesignSystem.sidebarTitlebarClearance)
        .padding(.horizontal, DesignSystem.spaceS)
        .padding(.bottom, DesignSystem.spaceS)
    }

    private var brand: some View {
        HStack(spacing: DesignSystem.spaceS) {
            AppMark(size: 40)

            Text("SYDownload")
                .font(.system(size: 15, weight: .semibold))

            Spacer(minLength: 0)
        }
        .frame(height: DesignSystem.sidebarBrandHeight)
        .padding(.horizontal, DesignSystem.spaceS)
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceS) {
            HStack(spacing: DesignSystem.spaceS) {
                Image(systemName: "lock.shield")
                Text("本地优先")
                    .foregroundStyle(.secondary)
            }
            Button {
                NotificationCenter.default.post(name: .syDownloadShowAbout, object: nil)
            } label: {
                Label("关于 SYDownload", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("关于 SYDownload")
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
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
