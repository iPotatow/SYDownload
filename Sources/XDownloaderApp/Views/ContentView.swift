#if canImport(SwiftUI)
import SwiftUI
import XDownloaderCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showsAbout = false

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if model.selection != .download {
                    Button {
                        model.selection = .download
                    } label: {
                        Label("新建下载", systemImage: "plus")
                    }
                    .help("新建下载")
                }

                Button {
                    showsAbout = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .help("关于 XDownloader")
            }
        }
        .sheet(isPresented: $showsAbout) {
            AboutView()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selection ?? .download {
        case .download:
            DownloadView(model: model)
        case .tasks:
            TasksView(model: model)
        case .history:
            HistoryView(model: model)
        case .xiaohongshu:
            PlatformLandingView(model: model, platform: .xiaohongshu)
        case .douyinTikTok:
            PlatformLandingView(model: model, platform: .douyin)
        case .settings:
            SettingsView(model: model)
        }
    }
}
#endif
