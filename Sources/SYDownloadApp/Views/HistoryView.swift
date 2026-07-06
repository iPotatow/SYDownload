#if canImport(SwiftUI)
import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @State private var selectedHistoryID: UUID?

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
                List(selection: $selectedHistoryID) {
                    ForEach(model.filteredHistory) { item in
                        HistoryRow(model: model, item: item)
                            .tag(item.id)
                            .contextMenu {
                                Button("打开位置", systemImage: "folder") {
                                    openFolder(item)
                                }
                                Button("打开原链接", systemImage: "safari") {
                                    openSource(item)
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
                .listStyle(.inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, DesignSystem.contentPadding)
        .padding(.top, DesignSystem.contentPadding)
        .padding(.bottom, DesignSystem.spaceL)
        .frame(maxWidth: DesignSystem.pageMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .searchable(text: $model.historySearch, prompt: "搜索标题、平台或链接")
        .onDeleteCommand(perform: removeSelectedHistory)
        .tint(DesignSystem.accent)
    }

    private func openFolder(_ item: HistoryItem) {
        NSWorkspace.shared.open(URL(fileURLWithPath: item.outputDirectory))
    }

    private func openSource(_ item: HistoryItem) {
        if let url = URL(string: item.sourceURL) {
            NSWorkspace.shared.open(url)
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

            Button("打开位置", systemImage: "folder") {
                NSWorkspace.shared.open(URL(fileURLWithPath: item.outputDirectory))
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("打开位置")

            Button("再次下载", systemImage: "arrow.down") {
                model.useHistory(item)
            }
            .buttonStyle(.borderless)
            .help("再次下载")

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
            .frame(width: 30)
        }
        .padding(.vertical, DesignSystem.spaceXS)
    }
}
#endif
