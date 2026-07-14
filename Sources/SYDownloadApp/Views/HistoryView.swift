#if canImport(SwiftUI)
import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @State private var selectedHistoryID: UUID?
    @FocusState private var searchFocused: Bool

    var body: some View {
        PageContainer(title: "历史记录") {
            TextField("搜索历史（标题、链接、平台）", text: $model.historySearch)
                .textFieldStyle(.roundedBorder)
                .font(DesignSystem.bodyFont)
                .frame(width: DesignSystem.pageHeaderSearchWidth, height: DesignSystem.controlHeightSmall)
                .focused($searchFocused)
                .accessibilityLabel("搜索历史记录")
        } content: {
            VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
                summaryBar
                Divider()

                if model.filteredHistory.isEmpty {
                    EmptyLibraryView(
                        systemImage: "clock.arrow.circlepath",
                        title: model.history.isEmpty ? "还没有下载历史" : "没有匹配的记录",
                        message: model.history.isEmpty ? "下载成功的内容会自动保存在这里。" : "清除搜索后查看全部历史记录。",
                        actionTitle: model.historySearch.isEmpty ? "去下载" : "清除搜索"
                    ) {
                        if model.historySearch.isEmpty {
                            model.selection = .download
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .syDownloadFocusDownloadInput, object: nil)
                            }
                        } else {
                            model.historySearch = ""
                            searchFocused = true
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedHistoryID) {
                        ForEach(model.filteredHistory) { item in
                            HistoryRow(model: model, item: item)
                                .tag(item.id)
                                .listRowInsets(
                                    EdgeInsets(
                                        top: DesignSystem.spaceXS,
                                        leading: 0,
                                        bottom: DesignSystem.spaceXS,
                                        trailing: 0
                                    )
                                )
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .contextMenu {
                                    Button("在 Finder 中显示", systemImage: "folder") {
                                        openFolder(item)
                                    }
                                    Button("打开原链接", systemImage: "safari") {
                                        openSource(item)
                                    }
                                    Button("再次下载", systemImage: "arrow.down") {
                                        prepareRedownload(item)
                                    }
                                    Divider()
                                    Button("从历史中删除", systemImage: "trash", role: .destructive) {
                                        removeHistory(item.id)
                                    }
                                }
                                .onTapGesture(count: 2) {
                                    openFolder(item)
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onDeleteCommand(perform: removeSelectedHistory)
        .onReceive(NotificationCenter.default.publisher(for: .syDownloadFocusSearch)) { _ in
            guard model.selection == .history else { return }
            searchFocused = true
        }
        .tint(DesignSystem.accent)
    }

    private var summaryBar: some View {
        HStack(alignment: .center, spacing: DesignSystem.spaceS) {
            Text("共 \(model.filteredHistory.count) 条记录")
                .font(DesignSystem.uiFont)
                .monospacedDigit()
            Spacer()
            Text("按完成时间排序")
                .font(DesignSystem.bodyFont)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: DesignSystem.controlRowMinHeight)
    }

    private func openFolder(_ item: HistoryItem) {
        NSWorkspace.shared.open(URL(fileURLWithPath: item.outputDirectory))
    }

    private func openSource(_ item: HistoryItem) {
        if let url = URL(string: item.sourceURL) {
            NSWorkspace.shared.open(url)
        }
    }

    private func prepareRedownload(_ item: HistoryItem) {
        model.prepareHistoryRedownload(item)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .syDownloadFocusDownloadInput, object: nil)
        }
    }

    private func removeHistory(_ id: UUID) {
        model.removeHistory(id)
        if selectedHistoryID == id {
            selectedHistoryID = nil
        }
    }

    private func removeSelectedHistory() {
        guard let selectedHistoryID else { return }
        removeHistory(selectedHistoryID)
    }
}

private struct HistoryRow: View {
    @ObservedObject var model: AppModel
    let item: HistoryItem

    var body: some View {
        HStack(spacing: DesignSystem.spaceM) {
            PlatformThumbnail(platform: item.platform, size: DesignSystem.controlHeightLarge)

            VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                Text("\(item.platform.displayName) · \(item.title)")
                    .font(DesignSystem.uiFont)
                    .lineLimit(1)

                Text(item.sourceURL)
                    .font(DesignSystem.metadataFont.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(item.completedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: DesignSystem.spaceM)

            Button("在 Finder 中显示", systemImage: "folder") {
                NSWorkspace.shared.open(URL(fileURLWithPath: item.outputDirectory))
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .frame(width: DesignSystem.controlHeightCompact, height: DesignSystem.controlHeightCompact)
            .help("在 Finder 中显示")

            Button("再次下载", systemImage: "arrow.down") {
                model.prepareHistoryRedownload(item)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .syDownloadFocusDownloadInput, object: nil)
                }
            }
            .buttonStyle(.borderless)
            .font(DesignSystem.uiFont)
            .frame(height: DesignSystem.controlHeightCompact)

            Menu {
                Button("打开原链接", systemImage: "safari") {
                    if let url = URL(string: item.sourceURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                Divider()
                Button("从历史中删除", systemImage: "trash", role: .destructive) {
                    model.removeHistory(item.id)
                }
            } label: {
                Label("更多操作", systemImage: "ellipsis")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .frame(width: DesignSystem.controlHeightCompact, height: DesignSystem.controlHeightCompact)
        }
        .padding(DesignSystem.spaceM)
        .frame(minHeight: DesignSystem.controlRowMinHeight)
        .background(
            DesignSystem.rowBackground,
            in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
                .strokeBorder(DesignSystem.hairline, lineWidth: DesignSystem.borderWidth)
        }
    }
}
#endif
