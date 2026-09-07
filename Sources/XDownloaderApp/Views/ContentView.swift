#if canImport(SwiftUI)
import SwiftUI
import XDownloaderCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showsAbout = false
    @State private var showsPhotos = false

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model, showsPhotos: $showsPhotos)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if showsPhotos || model.selection != .download {
                    Button {
                        showsPhotos = false
                        model.selection = .download
                    } label: {
                        Label("新建下载", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: [.command])
                    .help("新建下载（⌘N）")
                }

                Button {
                    showsAbout = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .help("关于 SYDownload")
            }
        }
        .sheet(isPresented: $showsAbout) {
            AboutView()
        }
        .onChange(of: model.selection) { _, newSelection in
            if newSelection != nil {
                showsPhotos = false
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if showsPhotos {
            PhotosView()
        } else {
            switch model.selection ?? .download {
            case .download:
                DownloadView(model: model)
            case .tasks:
                TasksView(model: model)
            case .history:
                HistoryView(model: model)
            case .settings:
                SettingsView(model: model)
            }
        }
    }
}
#endif
