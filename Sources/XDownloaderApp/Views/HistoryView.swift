#if canImport(SwiftUI)
import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("历史记录")
                    .font(.largeTitle.weight(.bold))
                Text(historySummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if model.filteredHistory.isEmpty {
                EmptyLibraryView(
                    systemImage: "clock.arrow.circlepath",
                    title: model.history.isEmpty ? "还没有下载历史" : "没有匹配的记录",
                    message: model.history.isEmpty ? "下载成功的内容会自动保存在这里。" : "尝试更换搜索关键词。",
                    actionTitle: "去下载"
                ) {
                    model.selection = .download
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(model.filteredHistory) { item in
                        HistoryRow(model: model, item: item)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 28)
        .padding(.bottom, 30)
        .frame(maxWidth: 820, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        HStack(spacing: 12) {
            PlatformThumbnail(platform: item.platform, size: 44)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.platform.displayName)
                    Text("·")
                    Text(item.completedAt.formatted(date: .abbreviated, time: .shortened))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Button("打开") {
                NSWorkspace.shared.open(URL(fileURLWithPath: item.outputDirectory))
            }

            Menu {
                Button("再次下载") { model.useHistory(item) }
                Button("打开原链接") {
                    if let url = URL(string: item.sourceURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                Divider()
                Button("从历史中删除", role: .destructive) {
                    model.removeHistory(item.id)
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .padding(.vertical, 5)
    }
}
#endif
