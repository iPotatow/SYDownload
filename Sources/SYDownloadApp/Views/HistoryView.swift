#if canImport(SwiftUI)
import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @State private var selectedHistoryID: UUID?
    @FocusState private var searchFocused: Bool

    var body: some View {
        PageContainer(title: "历史记录") {
            searchField
        } content: {
            VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
                summaryBar

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
                    historyList
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

    private var searchField: some View {
        HStack(spacing: DesignSystem.spaceS) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DesignSystem.textTertiary)
                .accessibilityHidden(true)

            TextField("搜索历史（标题、链接、平台）", text: $model.historySearch)
                .textFieldStyle(.plain)
                .font(DesignSystem.bodyFont)
                .focused($searchFocused)
        }
        .padding(.horizontal, DesignSystem.controlHorizontalPadding)
        .frame(width: DesignSystem.pageHeaderSearchWidth, height: DesignSystem.controlHeightSmall)
        .syInputSurface(isFocused: searchFocused)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("搜索历史记录")
    }

    private var summaryBar: some View {
        HStack(alignment: .center, spacing: DesignSystem.spaceS) {
            Text("共 \(model.filteredHistory.count) 条记录")
                .syTypography(DesignSystem.typographyControl)
                .foregroundStyle(DesignSystem.textPrimary)
                .monospacedDigit()

            Spacer()

            Label("按完成时间排序", systemImage: "arrow.down")
                .syTypography(DesignSystem.typographyCaption)
                .foregroundStyle(DesignSystem.textSecondary)
        }
        .frame(minHeight: DesignSystem.controlRowMinHeight)
    }

    private var historyList: some View {
        List(selection: $selectedHistoryID) {
            ForEach(Array(model.filteredHistory.enumerated()), id: \.element.id) { index, item in
                HistoryRow(
                    model: model,
                    item: item,
                    isSelected: selectedHistoryID == item.id,
                    showsDivider: index < model.filteredHistory.count - 1
                )
                .tag(item.id)
                .listRowInsets(EdgeInsets())
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
        .background(
            DesignSystem.panelBackground,
            in: RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    let isSelected: Bool
    let showsDivider: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignSystem.spaceM) {
            PlatformThumbnail(platform: item.platform, size: DesignSystem.controlHeightLarge)

            VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                Text(displayTitle)
                    .syTypography(DesignSystem.typographyControl)
                    .foregroundStyle(DesignSystem.textPrimary)
                    .lineLimit(1)

                Text(item.sourceURL)
                    .font(DesignSystem.metadataFont.monospaced())
                    .foregroundStyle(DesignSystem.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text("\(item.platform.displayName) · \(item.completedAt.formatted(date: .abbreviated, time: .shortened))")
                    .syTypography(DesignSystem.typographyCaption)
                    .foregroundStyle(DesignSystem.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: DesignSystem.spaceM)

            actions
                .frame(width: RefinementLayout.historyActionColumnWidth, alignment: .trailing)
        }
        .padding(.horizontal, RefinementLayout.libraryRowHorizontalPadding)
        .padding(.vertical, RefinementLayout.libraryRowVerticalPadding)
        .background(rowBackground)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(DesignSystem.divider)
                    .frame(height: DesignSystem.dividerWidth)
                    .padding(.leading, RefinementLayout.libraryRowHorizontalPadding + DesignSystem.controlHeightLarge + DesignSystem.spaceM)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(DesignSystem.motionFast, value: isHovered)
    }

    private var rowBackground: Color {
        if isSelected { return DesignSystem.selectionBackground }
        if isHovered { return DesignSystem.controlHoverBackground }
        return Color.clear
    }

    private var displayTitle: String {
        let prefix = "\(item.platform.displayName) · "
        guard item.title.hasPrefix(prefix) else { return item.title }
        return String(item.title.dropFirst(prefix.count))
    }

    private var actions: some View {
        HStack(spacing: DesignSystem.spaceS) {
            Button("在 Finder 中显示", systemImage: "folder") {
                NSWorkspace.shared.open(URL(fileURLWithPath: item.outputDirectory))
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .frame(width: DesignSystem.controlHeightCompact, height: DesignSystem.controlHeightCompact)
            .help("在 Finder 中显示")

            Menu {
                Button("打开原链接", systemImage: "safari") {
                    if let url = URL(string: item.sourceURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("再次下载", systemImage: "arrow.down") {
                    model.prepareHistoryRedownload(item)
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .syDownloadFocusDownloadInput, object: nil)
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
    }
}
#endif
