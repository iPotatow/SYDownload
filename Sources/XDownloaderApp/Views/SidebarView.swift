#if canImport(SwiftUI)
import SwiftUI
import XDownloaderCore

struct SidebarView: View {
    @ObservedObject var model: AppModel
    @Binding var showsPhotos: Bool

    var body: some View {
        List(selection: $model.selection) {
            Section {
                sidebarRow("下载", systemImage: "arrow.down.circle", value: .download)
                sidebarRow("任务", systemImage: "tray.full", value: .tasks)
                sidebarRow("历史记录", systemImage: "clock", value: .history)

                Button {
                    model.selection = nil
                    showsPhotos = true
                } label: {
                    Label("照片", systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 13, weight: showsPhotos ? .semibold : .regular))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(showsPhotos ? Color.accentColor.opacity(0.12) : Color.clear)
            }

            Section {
                sidebarRow("设置", systemImage: "gearshape", value: .settings)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 176, ideal: 196, max: 220)
    }

    @ViewBuilder
    private func sidebarRow(_ title: String, systemImage: String, value: AppSection) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 13, weight: model.selection == value ? .semibold : .regular))
            .tag(value)
    }
}
#endif
