#if canImport(SwiftUI)
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var focusedSection: AppSection?
    @State private var showsAbout = false
    @AppStorage("preferredAppearance") private var preferredAppearance = "跟随系统"

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                model: model,
                focusedSection: $focusedSection
            )
            .frame(
                minWidth: DesignSystem.sidebarWidth,
                maxWidth: DesignSystem.sidebarWidth,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .background(DesignSystem.sidebarBackground)
            .clipped()
            .layoutPriority(1)

            detail
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .background(DesignSystem.mainSurfaceBackground)
        }
        .frame(minWidth: 960, minHeight: 680, alignment: .topLeading)
        .background(DesignSystem.sidebarBackground)
        .ignoresSafeArea(.container, edges: .top)
        .tint(DesignSystem.accent)
        .preferredColorScheme(preferredAppearance == "浅色" ? .light : preferredAppearance == "深色" ? .dark : nil)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if model.selection != .download {
                    Button {
                        startNewDownload()
                    } label: {
                        Label("新建下载", systemImage: "plus")
                    }
                    .help("新建下载（⌘N）")
                }

                Button {
                    showsAbout = true
                } label: {
                    Label("关于 SYDownload", systemImage: "info.circle")
                }
                .labelStyle(.iconOnly)
                .help("关于 SYDownload")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .syDownloadNewDownload)) { _ in
            startNewDownload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .syDownloadShowAbout)) { _ in
            showsAbout = true
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
        case .photos:
            PhotosView()
        case .settings:
            SettingsView(model: model)
        }
    }

    private func startNewDownload() {
        model.selection = .download
        focusedSection = .download
    }
}
#endif
