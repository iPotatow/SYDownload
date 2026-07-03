#if canImport(SwiftUI)
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var focusedSection: AppSection?
    @State private var showsAbout = false
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

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
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    DesignSystem.mainSurfaceBackground,
                    in: RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous)
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(DesignSystem.purple.opacity(0.035))
                        .frame(width: 220, height: 220)
                        .blur(radius: 54)
                        .offset(x: 70, y: -90)
                        .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous))
                .shadow(color: DesignSystem.shadow, radius: 8, y: 3)
                .overlay {
                    if colorSchemeContrast == .increased {
                        RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous)
                            .stroke(DesignSystem.hairline, lineWidth: 1)
                    }
                }
                .padding(DesignSystem.mainSurfaceInsets)
                .clipped()
        }
        .frame(minWidth: 960, minHeight: 680, alignment: .topLeading)
        .background(DesignSystem.sidebarBackground)
        .ignoresSafeArea(.container, edges: .top)
        .tint(DesignSystem.accent)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if model.selection != .download {
                    Button {
                        model.selection = .download
                        focusedSection = .download
                    } label: {
                        Label("新建下载", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: [.command])
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
