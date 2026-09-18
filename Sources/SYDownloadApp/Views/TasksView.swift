#if canImport(SwiftUI)
import SwiftUI
import AppKit

struct TasksView: View {
    @ObservedObject var model: AppModel
    @State private var searchText = ""
    @State private var selectedTaskID: UUID?
    @FocusState private var searchFocused: Bool

    var body: some View {
        CorePageContainer(title: "任务", maxWidth: SYDownloadLayout.contentMaxWidth) {
            searchField
        } content: {
            VStack(alignment: .leading, spacing: CoreSpacing.l) {
                filterBar

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
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .syDownloadFocusDownloadInput, object: nil)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    taskTable
                }
            }
        }
        .onDeleteCommand(perform: removeSelectedTask)
        .onChange(of: model.taskFilter) { _, _ in
            selectedTaskID = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .syDownloadFocusSearch)) { _ in
            guard model.selection == .tasks else { return }
            searchFocused = true
        }
        .tint(CoreColor.accent)
    }

    private var searchField: some View {
        HStack(spacing: CoreSpacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CoreColor.textTertiary)
                .accessibilityHidden(true)

            TextField("搜索任务（标题、链接、平台）", text: $searchText)
                .textFieldStyle(.plain)
                .font(CoreTypography.bodyFont)
                .focused($searchFocused)
        }
        .padding(.horizontal, CoreMetrics.controlHorizontalPadding)
        .frame(width: SYDownloadLayout.pageHeaderSearchWidth, height: CoreMetrics.controlHeightSmall)
        .coreInputSurface(isFocused: searchFocused)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("搜索任务")
    }

    private var filterBar: some View {
        CenteredControl(width: RefinementLayout.taskFilterWidth) {
            Picker("任务状态", selection: $model.taskFilter) {
                ForEach(TaskFilter.allCases) { filter in
                    Text("\(filterTitle(filter)) \(count(for: filter))")
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .font(CoreTypography.controlFont)
            .frame(height: CoreMetrics.controlHeightDefault)
            .accessibilityLabel("任务状态")
        }
    }

    private var taskTable: some View {
        VStack(spacing: 0) {
            taskTableHeader

            Rectangle()
                .fill(CoreColor.divider)
                .frame(height: CoreMetrics.dividerWidth)

            List(selection: $selectedTaskID) {
                ForEach(Array(displayedTasks.enumerated()), id: \.element.id) { index, task in
                    TaskRow(
                        model: model,
                        task: task,
                        isSelected: selectedTaskID == task.id,
                        showsDivider: index < displayedTasks.count - 1
                    )
                    .tag(task.id)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .contextMenu {
                        taskContextMenu(task)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .background(
            CoreColor.panelBackground,
            in: RoundedRectangle(cornerRadius: CoreRadius.panel, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: CoreRadius.panel, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var taskTableHeader: some View {
        HStack(spacing: CoreSpacing.m) {
            Text("任务")
                .coreTypography(CoreTypography.groupLabel)
                .padding(.leading, CoreMetrics.controlHeightLarge + CoreSpacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("状态")
                .coreTypography(CoreTypography.groupLabel)
                .frame(width: RefinementLayout.taskStatusColumnWidth, alignment: .leading)

            Text("文件数")
                .coreTypography(CoreTypography.groupLabel)
                .frame(width: RefinementLayout.taskFileColumnWidth, alignment: .leading)

            Text("创建时间")
                .coreTypography(CoreTypography.groupLabel)
                .frame(width: RefinementLayout.taskDateColumnWidth, alignment: .leading)

            Text("操作")
                .coreTypography(CoreTypography.groupLabel)
                .frame(width: RefinementLayout.taskActionColumnWidth, alignment: .trailing)
        }
        .foregroundStyle(CoreColor.textSecondary)
        .padding(.horizontal, RefinementLayout.libraryRowHorizontalPadding)
        .frame(height: CoreMetrics.controlRowMinHeight)
    }

    @ViewBuilder
    private func taskContextMenu(_ task: DownloadTaskItem) -> some View {
        if task.state == .completed {
            Button("在 Finder 中显示", systemImage: "folder") {
                openFolder(task)
            }
        }

        if task.state == .failed || task.state == .cancelled {
            if let recovery = recoveryAction(for: task) {
                Button(recovery.title, systemImage: recovery.symbol) {
                    performRecovery(for: task)
                }
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
                || ($0.failureKind?.label.localizedCaseInsensitiveContains(query) ?? false)
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

    private func recoveryAction(for task: DownloadTaskItem) -> (title: String, symbol: String)? {
        switch task.failureKind {
        case .unsupported:
            return nil
        case .auth:
            return ("打开设置", "gearshape")
        case .disk:
            return ("更改保存位置", "folder")
        case .notFound:
            return ("打开原链接", "safari")
        case .rateLimited:
            return ("重试", "arrow.clockwise")
        case .validation, .timeout, .cancelled, .network, .verification, .engine, .unknown, .none:
            return ("重试", "arrow.clockwise")
        }
    }

    private func performRecovery(for task: DownloadTaskItem) {
        switch task.failureKind {
        case .auth, .disk:
            model.selection = .settings
        case .notFound:
            if let url = URL(string: task.sourceURL) {
                NSWorkspace.shared.open(url)
            }
        case .unsupported:
            break
        default:
            model.retryTask(task)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .syDownloadFocusDownloadInput, object: nil)
            }
        }
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
    let isSelected: Bool
    let showsDivider: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: CoreSpacing.m) {
            HStack(spacing: CoreSpacing.s) {
                PlatformThumbnail(platform: task.platform, size: CoreMetrics.controlHeightLarge)

                VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                    Text(displayTitle)
                        .coreTypography(CoreTypography.control)
                        .foregroundStyle(CoreColor.textPrimary)
                        .lineLimit(1)

                    Text(detailText)
                        .coreTypography(CoreTypography.caption)
                        .foregroundStyle(task.state == .failed ? CoreColor.danger : CoreColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    progress
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            StatusPill(state: task.state)
                .frame(width: RefinementLayout.taskStatusColumnWidth, alignment: .leading)

            Text(task.fileCount > 0 ? "\(task.fileCount)" : "—")
                .coreTypography(CoreTypography.body)
                .foregroundStyle(CoreColor.textSecondary)
                .monospacedDigit()
                .frame(width: RefinementLayout.taskFileColumnWidth, alignment: .leading)

            Text(task.createdAt.formatted(date: .numeric, time: .shortened))
                .coreTypography(CoreTypography.caption)
                .foregroundStyle(CoreColor.textSecondary)
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: RefinementLayout.taskDateColumnWidth, alignment: .leading)

            taskAction
                .frame(width: RefinementLayout.taskActionColumnWidth, alignment: .trailing)
        }
        .padding(.horizontal, RefinementLayout.libraryRowHorizontalPadding)
        .padding(.vertical, RefinementLayout.libraryRowVerticalPadding)
        .background(rowBackground)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(CoreColor.divider)
                    .frame(height: CoreMetrics.dividerWidth)
                    .padding(.leading, RefinementLayout.libraryRowHorizontalPadding + CoreMetrics.controlHeightLarge + CoreSpacing.s)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(CoreMotion.fast, value: isHovered)
    }

    private var rowBackground: Color {
        if isSelected { return CoreColor.selectionBackground }
        if isHovered { return CoreColor.controlHoverBackground }
        return Color.clear
    }

    private var displayTitle: String {
        let prefix = "\(task.platform.displayName) · "
        guard task.title.hasPrefix(prefix) else { return task.title }
        return String(task.title.dropFirst(prefix.count))
    }

    private var detailText: String {
        if let failureKind = task.failureKind,
           task.state == .failed || task.state == .cancelled {
            return "\(failureKind.label) · \(task.detail)"
        }
        return task.detail
    }

    @ViewBuilder
    private var progress: some View {
        if task.state == .downloading {
            HStack(spacing: CoreSpacing.s) {
                if let progress = task.progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(CoreColor.accent)
                    Text("\(Int(progress * 100))%")
                        .font(CoreTypography.captionFont.monospacedDigit())
                        .foregroundStyle(CoreColor.textSecondary)
                        .frame(width: CoreMetrics.controlHeightLarge, alignment: .trailing)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(CoreColor.accent)
                }
            }
            .frame(maxWidth: RefinementLayout.taskProgressMaxWidth)
        } else if task.state == .queued {
            ProgressView(value: 0)
                .progressViewStyle(.linear)
                .tint(CoreColor.accent)
                .frame(maxWidth: RefinementLayout.taskProgressMaxWidth)
        }
    }

    @ViewBuilder
    private var taskAction: some View {
        if task.state == .completed {
            HStack(spacing: CoreSpacing.s) {
                Button("在 Finder 中显示", systemImage: "folder") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: task.outputDirectory))
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .frame(width: CoreMetrics.controlHeightCompact, height: CoreMetrics.controlHeightCompact)
                .help("在 Finder 中显示")

                Menu {
                    Button("在 Finder 中显示", systemImage: "folder") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: task.outputDirectory))
                    }
                    Divider()
                    Button("移除任务", systemImage: "trash", role: .destructive) {
                        model.removeTask(task.id)
                    }
                } label: {
                    Label("更多操作", systemImage: "ellipsis")
                        .labelStyle(.iconOnly)
                }
                .menuStyle(.borderlessButton)
                .frame(width: CoreMetrics.controlHeightCompact, height: CoreMetrics.controlHeightCompact)
            }
        } else if task.state == .failed || task.state == .cancelled {
            recoveryButton
        } else {
            Button("取消", systemImage: "xmark") {
                model.cancelTask(task.id)
            }
            .buttonStyle(.bordered)
            .font(CoreTypography.controlFont)
            .frame(height: CoreMetrics.controlHeightSmall)
        }
    }

    @ViewBuilder
    private var recoveryButton: some View {
        switch task.failureKind {
        case .unsupported:
            EmptyView()
        case .auth:
            Button("打开设置", systemImage: "gearshape") {
                model.selection = .settings
            }
            .buttonStyle(.borderedProminent)
            .font(CoreTypography.controlFont)
            .frame(height: CoreMetrics.controlHeightSmall)
        case .disk:
            Button("更改保存位置", systemImage: "folder") {
                model.selection = .settings
            }
            .buttonStyle(.borderedProminent)
            .font(CoreTypography.controlFont)
            .frame(height: CoreMetrics.controlHeightSmall)
        case .notFound:
            Button("打开原链接", systemImage: "safari") {
                if let url = URL(string: task.sourceURL) {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .font(CoreTypography.controlFont)
            .frame(height: CoreMetrics.controlHeightSmall)
        default:
            Button("重试", systemImage: "arrow.clockwise") {
                model.retryTask(task)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .syDownloadFocusDownloadInput, object: nil)
                }
            }
            .buttonStyle(.borderedProminent)
            .font(CoreTypography.controlFont)
            .frame(height: CoreMetrics.controlHeightSmall)
        }
    }
}

struct EmptyLibraryView: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: CoreSpacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: CoreSpacing.xxl, weight: .regular))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(CoreTypography.sectionTitleFont)
            Text(message)
                .font(CoreTypography.bodyFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button(actionTitle, systemImage: "arrow.right", action: action)
                .buttonStyle(.borderedProminent)
                .font(CoreTypography.controlFont)
                .frame(height: CoreMetrics.controlHeightDefault)
        }
        .padding(CoreSpacing.xxl)
        .frame(maxWidth: .infinity)
    }
}
#endif
