#if canImport(SwiftUI)
import SwiftUI
import XDownloaderCore

struct SidebarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        List(selection: $model.selection) {
            Section {
                sidebarRow("下载", systemImage: "arrow.down.circle", value: .download)
                sidebarRow("任务", systemImage: "tray.full", value: .tasks)
                sidebarRow("历史记录", systemImage: "clock", value: .history)
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
