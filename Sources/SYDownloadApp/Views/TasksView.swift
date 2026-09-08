#if canImport(SwiftUI)
import AppKit
import SwiftUI

struct TasksView: View {
    @ObservedObject var model: AppModel
    @State private var searchText = ""
    @State private var selection = Set<UUID>()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
            PageHeader(
                title: "任务",
                subtitle: "管理下载任务，查看进度和状态。"
            )

            filterBar
            Divider()

            if displayedTasks.isEmpty {
                EmptyLibraryView(
                    systemImage: "tray",
                    title: hasTaskQuery ? "没有匹配的任务" : "还没有下载任务",
                    message: hasTaskQuery ? "清除搜索或筛选条件后查看全部任务。" : "粘贴链接并开始下载，任务会显示在这里。",
                    actionTitle: hasTaskQuery ? "清除筛选" : "新建下载"
                ) {
                    if hasTaskQuery {
                        model.taskFilter = .all
                        searchText = ""
                    } else {
                        model.selection = .download
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    ForEach(displayedTasks) { task in
                        TaskRow(model: model, task: task)
                            .tag(task.id)
                            .contextMenu {
                                taskContextMenu(task)
                            }
                            .onTapGesture(count: 2) {
                                performPrimaryAction(task)
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
        .searchable(text: $searchText, placement: .toolbar, prompt: "搜索任务")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("清空已完成", systemImage: "checkmark.circle") {
                    model.clearCompletedTasks()
                    selection = selection.filter { id in model.tasks.contains { $0.id == id } }
                }
                .disabled(completedCount == 0)
            }
        }
        .onDeleteCommand(perform: removeSelectedTasks)
        .tint(DesignSystem.accent)
    }

    private var filterBar: some View {
        HStack(spacing: 0) {
            ForEach(TaskFilter.allCases) { filter in
                Button {
                    model.taskFilter = filter
                } label: {
                    HStack(spacing: 5) {
                        Text(filterTitle(filter))
                        Text("\(count(for: filter))")
                            .monospacedDigit()
                            .foregroundStyle(model.taskFilter == filter ? DesignSystem.accent : Color.secondary)
                    }
                    .font(DesignSystem.supportingFont.weight(model.taskFilter == filter ? .semibold : .medium))
                    .padding(.horizontal, DesignSystem.spaceM)
                    .frame(height: 32)
                    .background(
                        model.taskFilter == filter ? DesignSystem.accentTint : Color.clear,
                        in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.taskFilter == filter ? .isSelected : [])
            }
        }
        .padding(2)
        .background(
            DesignSystem.rowBackground,
            in: RoundedRectangle(cornerRadius: DesignSystem.controlRadius, style: .continuous)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hasTaskQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.taskFilter != .all
    }

    private var displayedTasks: [DownloadTaskItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.filteredTasks }
        return model.filteredTasks.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.sourceURL.localizedCaseInsensitiveContains(query)
                || $0.platform.displayName.localizedCaseInsensitiveContains(query)
                || $0.detail.localizedCaseInsensitiveContains(query)
        }
    }

    @ViewBuilder
    private func taskContextMenu(_ task: DownloadTaskItem) -> some View {
        if task.state == .completed {
            Button("打开文件夹", systemImage: "folder") {
                openFolder(task)
            }
        }
        if task.state == .failed {
            Button("重试", systemImage: "arrow.clockwise") {
                model.retryTask(task)
            }
        }
        if task.state != .downloading {
            Divider()
            Button("移除任务", systemImage: "trash", role: .destructive) {
                model.removeTask(task.id)
                selection.remove(task.id)
            }
        }
    }

    private func performPrimaryAction(_ task: DownloadTaskItem) {
        switch task.state {
        case .completed:
            openFolder(task)
        case .failed:
            model.retryTask(task)
        case .queued, .downloading:
            break
        }
    }

    private func removeSelectedTasks() {
        let ids = selection
        for id in ids {
            model.removeTask(id)
        }
        selection = selection.filter { id in model.tasks.contains { $0.id == id } }
    }

    private func openFolder(_ task: DownloadTaskItem) {
        guard !task.outputDirectory.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: task.outputDirectory))
    }

    private func count(for filter: TaskFilter) -> Int {
        switch filter {
        case .all: return model.tasks.count
        case .active: return activeCount
        case .completed: return completedCount
        case .failed: return failedCount
        }
    }

    private func filterTitle(_ filter: TaskFilter) -> String {
        switch filter {
        case .failed: return "需处理"
        default: return filter.rawValue
        }
    }

    private var activeCount: Int {
        model.tasks.filter { $0.state == .queued || $0.state == .downloading }.count
    }

    private var completedCount: Int {
        model.tasks.filter { $0.state == .completed }.count
    }

    private var failedCount: Int {
        model.tasks.filter { $0.state == .failed }.count
    }
}

private struct TaskRow: View {
    @ObservedObject var model: AppModel
    let task: DownloadTaskItem

    var body: some View {
        HStack(spacing: DesignSystem.spaceM) {
            PlatformThumbnail(platform: task.platform, size: 42)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: DesignSystem.spaceS) {
                    Text(task.title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    StatusPill(state: task.state)
                }

                Text("\(task.platform.displayName) · \(task.detail)")
                    .font(DesignSystem.supportingFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if task.state == .downloading || task.state == .queued {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(DesignSystem.accent)
                        .frame(maxWidth: 460)
                } else {
                    Text(task.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(DesignSystem.metadataFont)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: DesignSystem.spaceM)

            if task.state == .failed {
                Button("重试", systemImage: "arrow.clockwise") {
                    model.retryTask(task)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, DesignSystem.spaceS)
    }
}

struct EmptyLibraryView: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.spaceM) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button(actionTitle, systemImage: "arrow.right", action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(DesignSystem.space2XL)
        .frame(maxWidth: .infinity)
    }
}
#endif
