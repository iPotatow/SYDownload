#if canImport(SwiftUI)
import SwiftUI
import XDownloaderCore

struct SidebarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
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
            .scrollContentBackground(.hidden)

            Divider()

            VStack(alignment: .leading, spacing: 3) {
                Text("XDownloader")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("开源 · GPL-3.0")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .navigationSplitViewColumnWidth(min: 170, ideal: 195, max: 220)
    }

    @ViewBuilder
    private func sidebarRow(_ title: String, systemImage: String, value: AppSection) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 14, weight: model.selection == value ? .semibold : .regular))
            .tag(value)
    }
}
#endif
