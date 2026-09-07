#if canImport(SwiftUI)
import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    eyebrow: "DOWNLOAD ARCHIVE",
                    title: "历史记录",
                    subtitle: historySummary,
                    systemImage: "clock.arrow.circlepath"
                )

                if model.filteredHistory.isEmpty {
                    EmptyLibraryView(
                        systemImage: "clock.arrow.circlepath",
                        title: model.history.isEmpty ? "还没有下载历史" : "没有匹配的记录",
                        message: model.history.isEmpty ? "下载成功的内容会自动保存在这里。" : "尝试更换搜索关键词。",
                        actionTitle: "去下载"
                    ) {
                        model.selection = .download
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(model.filteredHistory) { item in
                            HistoryRow(model: model, item: item)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.contentPadding)
            .padding(.top, DesignSystem.pageHeaderTop)
            .padding(.bottom, DesignSystem.space3XL)
            .frame(maxWidth: DesignSystem.pageMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .searchable(text: $model.historySearch, prompt: "搜索标题、平台或链接")
    }

    private var historySummary: String {
        if model.history.isEmpty { return "成功下载的内容会保存在这里，方便再次打开或下载。" }
        return "共保存 \(model.history.count) 条下载记录。"
    }
}

private struct HistoryRow: View {
    @ObservedObject var model: AppModel
    let item: HistoryItem

    var body: some View {
        SurfaceCard(padding: 16) {
            HStack(spacing: 14) {
                PlatformThumbnail(platform: item.platform, size: 54)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 9) {
                        Text(item.title)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                        PlatformChip(platform: item.platform, selected: true)
                    }

                    HStack(spacing: 6) {
                        Text(item.completedAt.formatted(date: .abbreviated, time: .shortened))
                        Text("·")
                        Text(item.outputDirectory)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                    Text(item.sourceURL)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 12)

                Button("打开位置", systemImage: "folder", action: openFolder)
                    .buttonStyle(.borderless)

                Menu {
                    Button("再次下载", systemImage: "arrow.down") { model.useHistory(item) }
                    Button("打开原链接", systemImage: "safari") { openSource() }
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
        }
    }

    private func openFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: item.outputDirectory))
    }

    private func openSource() {
        guard let url = URL(string: item.sourceURL) else { return }
        NSWorkspace.shared.open(url)
    }
}
#endif
