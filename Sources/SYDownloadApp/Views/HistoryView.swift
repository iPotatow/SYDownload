#if canImport(SwiftUI)
import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
                HStack(alignment: .top, spacing: DesignSystem.spaceL) {
                    PageHeader(
                        title: "历史记录",
                        subtitle: "保留最近的下载记录，快速回到原始文件夹。"
                    )

                    Spacer(minLength: DesignSystem.spaceL)
                    searchField
                }

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
                        actionTitle: "去下载"
                    ) {
                        model.selection = .download
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(model.filteredHistory) { item in
                            HistoryRow(model: model, item: item)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.contentPadding)
            .padding(.top, DesignSystem.pageTitlebarClearance + DesignSystem.pageHeaderTop)
            .padding(.bottom, DesignSystem.space2XL)
            .frame(maxWidth: DesignSystem.pageMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .tint(DesignSystem.accent)
    }

    private var searchField: some View {
        HStack(spacing: DesignSystem.spaceS) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索标题、平台或链接", text: $model.historySearch)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, DesignSystem.spaceM)
        .frame(width: 260, height: 32)
        .background(
            DesignSystem.warmSurface,
            in: RoundedRectangle(cornerRadius: DesignSystem.controlRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.controlRadius, style: .continuous)
                .strokeBorder(DesignSystem.hairline)
        }
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

                Button("打开位置", systemImage: "folder", action: openFolder)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("打开位置")

                Menu {
                    Button("再次下载", systemImage: "arrow.down") {
                        model.useHistory(item)
                    }
                    Button("打开原链接", systemImage: "safari") {
                        openSource()
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
        }
    }

    private func openFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: item.outputDirectory))
    }

    private func openSource() {
        if let url = URL(string: item.sourceURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
#endif
