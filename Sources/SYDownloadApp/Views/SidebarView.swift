#if canImport(SwiftUI)
import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: AppModel
    let focusedSection: FocusState<AppSection?>.Binding

    var body: some View {
        VStack(spacing: 0) {
            brand

            VStack(spacing: DesignSystem.spaceXS) {
                sectionLabel("工作区")
                sidebarButton(.download, title: "下载", systemImage: "arrow.down.circle.fill")
                sidebarButton(.tasks, title: "任务", systemImage: "tray.full.fill")
                sidebarButton(.history, title: "历史记录", systemImage: "clock.arrow.circlepath")

                sectionLabel("工具")
                sidebarButton(.photos, title: "照片整理", systemImage: "photo.on.rectangle.angled")

                sectionLabel("偏好")
                sidebarButton(.settings, title: "设置", systemImage: "slider.horizontal.3")
            }
            .padding(.horizontal, DesignSystem.spaceS)

            Spacer(minLength: DesignSystem.spaceXL)

            sidebarFooter
        }
    }

    private var brand: some View {
        VStack(spacing: 6) {
            AppMark(size: 56)
            Text("SYDownload")
                .font(DesignSystem.sectionTitleFont)
            Text("媒体下载工作台")
                .font(DesignSystem.supportingFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 42)
        .padding(.bottom, DesignSystem.spaceXL)
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("两个下载引擎已接入", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
            Text("Apple Silicon · macOS 14+")
                .foregroundStyle(.tertiary)
        }
        .font(DesignSystem.metadataFont)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.spaceL)
        .padding(.bottom, DesignSystem.spaceL)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(DesignSystem.metadataFont.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.spaceM)
            .padding(.top, DesignSystem.spaceS)
            .accessibilityAddTraits(.isHeader)
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
        .buttonStyle(SidebarButtonStyle(selected: selected, isFocused: focusedSection.wrappedValue == section))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
#endif
