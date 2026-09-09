#if canImport(SwiftUI)
import SwiftUI
import AppKit

struct TasksView: View {
    @ObservedObject var model: AppModel
    @State private var searchText = ""
    @State private var selectedTaskID: UUID?
    @FocusState private var searchFocused: Bool

    var body: some View {
        PageContainer(title: "任务") {
            TextField("搜索任务（标题、链接、平台）", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .font(DesignSystem.bodyFont)
                .frame(width: DesignSystem.pageHeaderSearchWidth, height: DesignSystem.controlHeightSmall)
                .focused($searchFocused)
                .accessibilityLabel("搜索任务")
        } content: {
            VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
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
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .syDownloadFocusDownloadInput, object: nil)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedTaskID) {
                        ForEach(displayedTasks) { task in
                            TaskRow(model: model, task: task)
                                .tag(task.id)
                                .listRowInsets(
                                    EdgeInsets(
                                        top: DesignSystem.spaceXS,
                                        leading: 0,
                                        bottom: DesignSystem.spaceXS,
                                        trailing: 0
                                    )
                                )
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .contextMenu {
                                    taskContextMenu(task)
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .font(DesignSystem.uiFont)
        .frame(height: DesignSystem.controlHeightDefault)
        .accessibilityLabel("任务状态")
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

    var body: some View {
        HStack(spacing: DesignSystem.spaceM) {
            PlatformThumbnail(platform: task.platform, size: DesignSystem.controlHeightLarge)

            VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                HStack(spacing: DesignSystem.spaceS) {
                    Text(task.title)
                        .font(DesignSystem.uiFont)
                        .lineLimit(1)
                    StatusPill(state: task.state)
                }

                Text(detailText)
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(task.state == .failed ? DesignSystem.destructive : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if task.state == .downloading {
                    HStack(spacing: DesignSystem.spaceS) {
                        if let progress = task.progress {
                            ProgressView(value: progress)
                                .progressViewStyle(.linear)
                                .tint(DesignSystem.accent)
                            Text("\(Int(progress * 100))%")
                                .font(DesignSystem.metadataFont.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: DesignSystem.controlHeightLarge, alignment: .trailing)
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

            taskAction
        }
        .padding(DesignSystem.spaceM)
        .frame(minHeight: DesignSystem.controlRowMinHeight)
        .background(
            DesignSystem.rowBackground,
            in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
                .strokeBorder(DesignSystem.hairline, lineWidth: DesignSystem.borderWidth)
        }
        .contentShape(Rectangle())
    }

    private var detailText: String {
        if let failureKind = task.failureKind,
           task.state == .failed || task.state == .cancelled {
            return "\(failureKind.label) · \(task.detail)"
        }
        return "\(task.platform.displayName) · \(task.detail)"
    }

    @ViewBuilder
    private var taskAction: some View {
        if task.state == .completed {
            Button("在 Finder 中显示", systemImage: "folder") {
                NSWorkspace.shared.open(URL(fileURLWithPath: task.outputDirectory))
            }
            .buttonStyle(.bordered)
            .font(DesignSystem.uiFont)
            .frame(height: DesignSystem.controlHeightDefault)
        } else if task.state == .failed || task.state == .cancelled {
            recoveryButton
        } else {
            Button("取消", systemImage: "xmark") {
                model.cancelTask(task.id)
            }
            .buttonStyle(.bordered)
            .font(DesignSystem.uiFont)
            .frame(height: DesignSystem.controlHeightDefault)
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
            .font(DesignSystem.uiFont)
            .frame(height: DesignSystem.controlHeightDefault)
        case .disk:
            Button("更改保存位置", systemImage: "folder") {
                model.selection = .settings
            }
            .buttonStyle(.borderedProminent)
            .font(DesignSystem.uiFont)
            .frame(height: DesignSystem.controlHeightDefault)
        case .notFound:
            Button("打开原链接", systemImage: "safari") {
                if let url = URL(string: task.sourceURL) {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .font(DesignSystem.uiFont)
            .frame(height: DesignSystem.controlHeightDefault)
        default:
            Button("重试", systemImage: "arrow.clockwise") {
                model.retryTask(task)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .syDownloadFocusDownloadInput, object: nil)
                }
            }
            .buttonStyle(.borderedProminent)
            .font(DesignSystem.uiFont)
            .frame(height: DesignSystem.controlHeightDefault)
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
        VStack(spacing: DesignSystem.spaceM) {
            Image(systemName: systemImage)
                .font(.system(size: DesignSystem.space2XL, weight: .regular))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(DesignSystem.sectionTitleFont)
            Text(message)
                .font(DesignSystem.bodyFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button(actionTitle, systemImage: "arrow.right", action: action)
                .buttonStyle(.borderedProminent)
                .font(DesignSystem.uiFont)
                .frame(height: DesignSystem.controlHeightDefault)
        }
        .padding(DesignSystem.space2XL)
        .frame(maxWidth: .infinity)
    }
}
#endif
