#if canImport(SwiftUI)
import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
                PageHeader(eyebrow: "DOWNLOAD ARCHIVE", title: "历史记录", subtitle: historySummary, systemImage: "clock.arrow.circlepath")

                HStack(spacing: DesignSystem.spaceM) {
                    Label("归档", systemImage: "archivebox")
                        .font(DesignSystem.uiFont)
                    Text("\(model.history.count) 条记录")
                        .font(.headline.monospacedDigit())
                    if !model.historySearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("筛选：\"\(model.historySearch)\"")
                            .font(DesignSystem.supportingFont)
                            .foregroundStyle(DesignSystem.accentSecondary)
                    }
                    Spacer()
                    Text("按完成时间排序")
                        .font(DesignSystem.supportingFont)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DesignSystem.spaceM)
                .padding(.vertical, DesignSystem.spaceS)
                .background(DesignSystem.rowBackground, in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous))

                HStack {
                    Text("归档内容").font(DesignSystem.sectionTitleFont)
                    Text("\(model.filteredHistory.count) 项").font(DesignSystem.supportingFont).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    Text("搜索标题、平台或链接").font(DesignSystem.supportingFont).foregroundStyle(.secondary)
                }

                if model.filteredHistory.isEmpty {
                    EmptyLibraryView(
                        systemImage: "clock.arrow.circlepath",
                        title: model.history.isEmpty ? "还没有下载历史" : "没有匹配的记录",
                        message: model.history.isEmpty ? "下载成功的内容会自动保存在这里。" : "尝试更换搜索关键词。",
                        actionTitle: "去下载"
                    ) { model.selection = .download }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(model.filteredHistory) { item in HistoryRow(model: model, item: item) }
                    }
                    .padding(.horizontal, DesignSystem.spaceS)
                }
            }
            .padding(.horizontal, DesignSystem.contentPadding)
            .padding(.top, DesignSystem.pageTitlebarClearance + DesignSystem.pageHeaderTop)
            .padding(.bottom, DesignSystem.space2XL)
            .frame(maxWidth: DesignSystem.pageMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .searchable(text: $model.historySearch, prompt: "搜索标题、平台或链接")
        .tint(DesignSystem.accent)
    }

    private var historySummary: String {
        model.history.isEmpty ? "成功下载的内容会保存在这里，方便再次打开或下载。" : "保留最近的下载记录，快速回到原始文件夹。"
    }
}

private struct HistoryRow: View {
    @ObservedObject var model: AppModel
    let item: HistoryItem

    var body: some View {
        InsetRow {
            HStack(spacing: DesignSystem.spaceM) {
                PlatformThumbnail(platform: item.platform, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: DesignSystem.spaceS) {
                        Text(item.title).font(.headline.weight(.semibold)).lineLimit(1)
                        PlatformChip(platform: item.platform, selected: true)
                    }
                    Text(item.sourceURL).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    Text("完成于 \(item.completedAt.formatted(date: .abbreviated, time: .shortened)) · \(item.outputDirectory)")
                        .font(DesignSystem.metadataFont).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 8)
                Button("打开位置", systemImage: "folder", action: openFolder).buttonStyle(.borderless)
                Menu {
                    Button("再次下载", systemImage: "arrow.down") { model.useHistory(item) }
                    Button("打开原链接", systemImage: "safari") { openSource() }
                    Divider()
                    Button("从历史中删除", systemImage: "trash", role: .destructive) { model.removeHistory(item.id) }
                } label: {
                    Label("更多操作", systemImage: "ellipsis").labelStyle(.iconOnly)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 30)
            }
        }
    }

    private func openFolder() { NSWorkspace.shared.open(URL(fileURLWithPath: item.outputDirectory)) }
    private func openSource() { if let url = URL(string: item.sourceURL) { NSWorkspace.shared.open(url) } }
}
#endif
