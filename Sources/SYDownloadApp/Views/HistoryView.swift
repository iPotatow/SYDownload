#if canImport(SwiftUI)
import AppKit
import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @State private var selection = Set<UUID>()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
            PageHeader(
                title: "历史记录",
                subtitle: "保留最近的下载记录，快速回到原始文件夹。"
            )

            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.spaceS) {
                Text("共 \(model.filteredHistory.count) 条记录")
                    .font(DesignSystem.uiFont.weight(.semibold))
                    .monospacedDigit()
                Spacer()
                Text("按完成时间排序")
                    .font(DesignSystem.supportingFont)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if model.filteredHistory.isEmpty {
                EmptyLibraryView(
                    systemImage: "clock.arrow.circlepath",
                    title: model.history.isEmpty ? "还没有下载历史" : "没有匹配的记录",
                    message: model.history.isEmpty ? "下载成功的内容会自动保存在这里。" : "尝试更换搜索关键词。",
                    actionTitle: model.historySearch.isEmpty ? "去下载" : "清除搜索"
                ) {
                    if model.historySearch.isEmpty {
                        model.selection = .download
                    } else {
                        model.historySearch = ""
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    ForEach(model.filteredHistory) { item in
                        HistoryRow(model: model, item: item)
                            .tag(item.id)
                            .contextMenu {
                                historyContextMenu(item)
                            }
                            .onTapGesture(count: 2) {
                                openFolder(item)
                            }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(DesignSystem.contentPadding)
        .padding(.bottom, DesignSystem.space2XL)
        .frame(maxWidth: DesignSystem.pageMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .searchable(text: $model.historySearch, placement: .toolbar, prompt: "搜索标题、平台或链接")
        .onDeleteCommand(perform: removeSelectedHistory)
        .tint(DesignSystem.accent)
    }

    @ViewBuilder
    private func historyContextMenu(_ item: HistoryItem) -> some View {
        Button("再次下载", systemImage: "arrow.down") {
            model.useHistory(item)
        }
        Button("打开位置", systemImage: "folder") {
            openFolder(item)
        }
        Button("打开原链接", systemImage: "safari") {
            openSource(item)
        }
        Divider()
        Button("从历史中删除", systemImage: "trash", role: .destructive) {
            model.removeHistory(item.id)
            selection.remove(item.id)
        }
    }

    private func removeSelectedHistory() {
        let ids = selection
        for id in ids {
            model.removeHistory(id)
        }
        selection.removeAll()
    }

    private func openFolder(_ item: HistoryItem) {
        guard !item.outputDirectory.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: item.outputDirectory))
    }

    private func openSource(_ item: HistoryItem) {
        if let url = URL(string: item.sourceURL) {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct HistoryRow: View {
    @ObservedObject var model: AppModel
    let item: HistoryItem

    var body: some View {
        HStack(spacing: DesignSystem.spaceM) {
            PlatformThumbnail(platform: item.platform, size: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(item.platform.displayName) · \(item.title)")
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)

                Text(item.sourceURL)
                    .font(DesignSystem.supportingFont.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(item.completedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: DesignSystem.spaceM)

            Button("再次下载", systemImage: "arrow.down") {
                model.useHistory(item)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, DesignSystem.spaceS)
    }
}
#endif
