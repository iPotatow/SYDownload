#if canImport(SwiftUI)
import SwiftUI
import AppKit

struct TasksView: View {
    @ObservedObject var model: AppModel
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
                HStack(alignment: .top, spacing: DesignSystem.spaceL) {
                    PageHeader(
                        title: "任务",
                        subtitle: "管理下载任务，查看进度和状态。"
                    )

                    Spacer(minLength: DesignSystem.spaceL)

                    Button("清空已完成", systemImage: "checkmark.circle", action: model.clearCompletedTasks)
                        .buttonStyle(.borderless)
                        .disabled(completedCount == 0)
                }

                toolbar
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
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(displayedTasks) { task in
                            TaskRow(model: model, task: task)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.contentPadding)
            .padding(.top, DesignSystem.contentPadding)
            .padding(.bottom, DesignSystem.space2XL)
            .frame(maxWidth: DesignSystem.pageMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .tint(DesignSystem.accent)
    }

    private var toolbar: some View {
        HStack(spacing: DesignSystem.spaceM) {
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

            Spacer(minLength: DesignSystem.spaceM)

            HStack(spacing: DesignSystem.spaceS) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索任务…", text: $searchText)
                    .accessibilityLabel("搜索任务")
                    .focused($searchFocused)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, DesignSystem.spaceM)
            .frame(width: 190, height: 32)
            .background(
                DesignSystem.warmSurface,
                in: RoundedRectangle(cornerRadius: DesignSystem.controlRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.controlRadius, style: .continuous)
                    .strokeBorder(searchFocused ? DesignSystem.accent : DesignSystem.hairline, lineWidth: searchFocused ? 2 : 1)
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
        model.tasks.filter { $0.state == .failed }.count
    }
}

private struct TaskRow: View {
    @ObservedObject var model: AppModel
    let task: DownloadTaskItem

    var body: some View {
        InsetRow {
            HStack(spacing: DesignSystem.spaceM) {
                PlatformThumbnail(platform: task.platform, size: 46)

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
                        .fixedSize(horizontal: false, vertical: true)

                    if task.state == .downloading || task.state == .queued {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .tint(DesignSystem.accent)
                            .frame(maxWidth: 460)
                    } else if let progress = task.progress {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(DesignSystem.success)
                            .frame(maxWidth: 460)
                    }
                }

                Spacer(minLength: DesignSystem.spaceM)

                if task.state == .completed {
                    Button("打开文件夹", systemImage: "folder", action: openFolder)
                        .buttonStyle(.borderless)
                } else if task.state == .failed {
                    Button("重试", systemImage: "arrow.clockwise") {
                        model.retryTask(task)
                    }
                    .buttonStyle(.bordered)
                }

                if task.state != .downloading {
                    Button("移除任务", systemImage: "xmark", action: removeTask)
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    private func openFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: task.outputDirectory))
    }

    private func removeTask() {
        model.removeTask(task.id)
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
