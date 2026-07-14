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
                .background(
                    DesignSystem.mainSurfaceBackground,
                    in: RoundedRectangle(cornerRadius: DesignSystem.contentRadius, style: .continuous)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: DesignSystem.contentRadius, style: .continuous)
                )
                .syContentSurfaceShadow()
                .padding(DesignSystem.mainSurfaceInsets)
        }
        .frame(
            minWidth: DesignSystem.windowWidth,
            minHeight: DesignSystem.windowHeight,
            alignment: .topLeading
        )
        .background(DesignSystem.windowBackground)
        .ignoresSafeArea(.container, edges: .top)
        .tint(DesignSystem.accent)
        .preferredColorScheme(preferredAppearance == "浅色" ? .light : preferredAppearance == "深色" ? .dark : nil)
        .onReceive(NotificationCenter.default.publisher(for: .syDownloadNewDownload)) { _ in
            model.selection = .download
            focusedSection = .download
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .syDownloadFocusDownloadInput, object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .syDownloadShowAbout)) { _ in
            showsAbout = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .syDownloadShowSettings)) { _ in
            model.selection = .settings
            focusedSection = .settings
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
}
#endif
