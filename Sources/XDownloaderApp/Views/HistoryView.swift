#if canImport(SwiftUI)
import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("历史记录").font(.system(size: 28, weight: .bold))

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索标题、平台或链接…", text: $model.historySearch).textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1) }

            if model.filteredHistory.isEmpty {
                EmptyLibraryView(systemImage: "clock.arrow.circlepath", title: model.history.isEmpty ? "还没有下载历史" : "没有匹配的记录", message: model.history.isEmpty ? "下载成功的内容会自动保存在这里。" : "尝试更换搜索关键词。", actionTitle: "去下载") { model.selection = .download }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.filteredHistory) { item in HistoryRow(model: model, item: item) }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: 780, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct HistoryRow: View {
    @ObservedObject var model: AppModel
    let item: HistoryItem

    var body: some View {
        HStack(spacing: 12) {
            PlatformThumbnail(platform: item.platform, size: 52)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.platform.displayName).foregroundStyle(item.platform == .xiaohongshu ? Color.red : Color.secondary)
                    Text("·")
                    Text(item.completedAt.formatted(date: .abbreviated, time: .shortened))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button("打开") { NSWorkspace.shared.open(URL(fileURLWithPath: item.outputDirectory)) }.buttonStyle(.bordered)
            Menu {
                Button("再次下载") { model.useHistory(item) }
                Button("打开原链接") {
                    if let url = URL(string: item.sourceURL) { NSWorkspace.shared.open(url) }
                }
                Divider()
                Button("从历史中删除", role: .destructive) { model.removeHistory(item.id) }
            } label: { Image(systemName: "ellipsis") }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .padding(10)
        .designCard()
    }
}
#endif
