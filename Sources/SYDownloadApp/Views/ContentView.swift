#if canImport(SwiftUI)
import SwiftUI
import AppKit

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
                minWidth: SYDownloadLayout.sidebarWidth,
                maxWidth: SYDownloadLayout.sidebarWidth,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .background(.regularMaterial)
            .clipped()
            .layoutPriority(1)

            detail
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .background(CoreColor.contentBackground, in: RoundedRectangle(cornerRadius: CoreRadius.content, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: CoreRadius.content, style: .continuous))
                .coreContentSurfaceShadow()
                .padding(SYDownloadLayout.contentSurfaceInsets)
        }
        .frame(
            minWidth: SYDownloadLayout.windowWidth,
            minHeight: SYDownloadLayout.windowHeight,
            alignment: .topLeading
        )
        .background(CoreColor.windowBackground)
        .ignoresSafeArea(.container, edges: .top)
        .tint(CoreColor.accent)
        .preferredColorScheme(preferredAppearance == "浅色" ? .light : preferredAppearance == "深色" ? .dark : nil)
        .onReceive(NotificationCenter.default.publisher(for: .syDownloadNewDownload)) { _ in
            model.requestSelection(.download)
            if model.selection == .download {
                focusedSection = .download
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .syDownloadFocusDownloadInput, object: nil)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .syDownloadShowAbout)) { _ in
            showsAbout = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .syDownloadShowSettings)) { _ in
            model.openSettings(.general)
            focusedSection = .settings
        }
        .alert("保存设置更改？", isPresented: $model.showsUnsavedSettingsPrompt) {
            Button("保存") {
                Task { _ = await model.saveUnsavedSettingsAndContinue() }
            }
            Button("放弃更改", role: .destructive) {
                Task { await model.discardUnsavedSettingsAndContinue() }
            }
            Button("取消", role: .cancel) {
                model.cancelUnsavedSettingsPrompt()
            }
        } message: {
            Text("小红书或抖音设置还有未保存的更改。")
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
            PhotosView(state: model.photoWorkspace)
        case .exif:
            ExifEditorView(model: model.exifEditor)
        case .settings:
            SettingsView(model: model)
        }
    }
}
#endif
