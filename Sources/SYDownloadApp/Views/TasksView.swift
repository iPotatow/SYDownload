#if canImport(SwiftUI)
import SwiftUI
import AppKit

struct TasksView: View {
    @ObservedObject var model: AppModel
    @State private var searchText = ""
    @State private var selectedTaskID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
            PageHeader(
                title: "任务",
                subtitle: "最多 3 个任务并行下载，可查看实时写入进度、取消任务和处理失败。"
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
                List(selection: $selectedTaskID) {
                    ForEach(displayedTasks) { task in
                        TaskRow(model: model, task: task)
                            .tag(task.id)
                            .contextMenu {
                                taskContextMenu(task)
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
        .onDeleteCommand(perform: removeSelectedTask)
        .onChange(of: model.taskFilter) { _, _ in
            selectedTaskID = nil
        }
        .tint(DesignSystem.accent)
    }

    private var filterBar: some View {
        Picker("任务状态", selection: $model.taskFilter) {
            ForEach(TaskFilter.allCases) { filter in
                Text("\(filterTitle(filter)) \(count(for: filter))")
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("任务状态")
    }

    @ViewBuilder
    private func taskContextMenu(_ task: DownloadTaskItem) -> some View {
        if task.state == .completed {
            Button("打开文件夹", systemImage: "folder") {
                openFolder(task)
            }
        }
        if task.state == .failed || task.state == .cancelled {
            Button("重试", systemImage: "arrow.clockwise") {
                model.retryTask(task)
            }
        }
        if task.state == .queued || task.state == .downloading {
            Button("取消任务", systemImage: "xmark.circle", role: .destructive) {
                model.cancelTask(task.id)
            }
        } else {
            Divider()
            Button("移除任务", systemImage: "trash", role: .destructive) {
                model.removeTask(task.id)
                if selectedTaskID == task.id {
                    selectedTaskID = nil
                }
            }
        }
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
        model.tasks.filter { $0.state == .failed || $0.state == .cancelled }.count
    }

    private func openFolder(_ task: DownloadTaskItem) {
        NSWorkspace.shared.open(URL(fileURLWithPath: task.outputDirectory))
    }

    private func removeSelectedTask() {
        guard let selectedTaskID,
              let task = model.tasks.first(where: { $0.id == selectedTaskID }),
              task.state != .downloading,
              task.state != .queued else { return }
        model.removeTask(selectedTaskID)
        self.selectedTaskID = nil
    }
}

private struct TaskRow: View {
    @ObservedObject var model: AppModel
    let task: DownloadTaskItem

    var body: some View {
        HStack(spacing: DesignSystem.spaceM) {
            PlatformThumbnail(platform: task.platform, size: 42)

            VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                HStack(spacing: DesignSystem.spaceS) {
                    Text(task.title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    StatusPill(state: task.state)
                }

                Text("\(task.platform.displayName) · \(task.detail)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if task.state == .downloading {
                    HStack(spacing: DesignSystem.spaceS) {
                        if let progress = task.progress {
                            ProgressView(value: progress)
                                .progressViewStyle(.linear)
                                .tint(DesignSystem.accent)
                            Text("\(Int(progress * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 38, alignment: .trailing)
                        } else {
                            ProgressView()
                                .progressViewStyle(.linear)
                                .tint(DesignSystem.accent)
                        }
                    }
                    .frame(maxWidth: 460)
                } else if task.state == .queued {
                    ProgressView(value: 0)
                        .progressViewStyle(.linear)
                        .tint(DesignSystem.accent)
                        .frame(maxWidth: 460)
                }
            }

            Spacer(minLength: DesignSystem.spaceM)

            if task.state == .completed {
                Button("打开文件夹", systemImage: "folder") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: task.outputDirectory))
                }
                .buttonStyle(.borderless)
            } else if task.state == .failed || task.state == .cancelled {
                Button("重试", systemImage: "arrow.clockwise") {
                    model.retryTask(task)
                }
                .buttonStyle(.bordered)
            } else {
                Button("取消", systemImage: "xmark") {
                    model.cancelTask(task.id)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, DesignSystem.spaceXS)
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
