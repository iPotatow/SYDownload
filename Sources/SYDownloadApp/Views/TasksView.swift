#if canImport(SwiftUI)
import SwiftUI
import AppKit

struct TasksView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 18) {
                    PageHeader(
                        eyebrow: "DOWNLOAD QUEUE",
                        title: "下载任务",
                        subtitle: taskSummary,
                        systemImage: "tray.full"
                    )
                    Spacer(minLength: 12)
                    Button("清空已完成", systemImage: "checkmark.circle", action: model.clearCompletedTasks)
                        .buttonStyle(.bordered)
                        .disabled(!model.tasks.contains(where: { $0.state == .completed }))
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    MetricCard(label: "全部任务", value: "\(model.tasks.count)", detail: "已加入工作台", systemImage: "tray")
                    MetricCard(label: "进行中", value: "\(activeCount)", detail: "等待或下载中", systemImage: "arrow.down.circle", tint: DesignSystem.accent)
                    MetricCard(label: "已完成", value: "\(completedCount)", detail: "可以在历史记录中找到", systemImage: "checkmark.circle", tint: DesignSystem.success)
                    MetricCard(label: "需要处理", value: "\(failedCount)", detail: "失败任务", systemImage: "exclamationmark.triangle", tint: DesignSystem.destructive)
                }

                Picker("任务筛选", selection: $model.taskFilter) {
                    ForEach(TaskFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)

                if model.filteredTasks.isEmpty {
                    EmptyLibraryView(
                        systemImage: "tray",
                        title: model.tasks.isEmpty ? "还没有下载任务" : "这个分类暂时为空",
                        message: "粘贴链接并开始下载后，任务会显示在这里。",
                        actionTitle: "新建下载"
                    ) {
                        model.selection = .download
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(model.filteredTasks) { task in
                            TaskRow(model: model, task: task)
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
    }

    private var taskSummary: String {
        if model.tasks.isEmpty { return "进行中的下载和完成状态会集中显示在这里。" }
        return "当前显示 \(model.filteredTasks.count) 个任务，共 \(model.tasks.count) 个。"
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
        SurfaceCard(padding: 16) {
            HStack(spacing: 14) {
                PlatformThumbnail(platform: task.platform, size: 52)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(task.title)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                        StatusPill(state: task.state)
                    }

                    HStack(spacing: 6) {
                        Text(task.platform.displayName)
                        Text("·")
                        Text(task.detail)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                    if task.state == .downloading || task.state == .queued {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .tint(DesignSystem.accent)
                            .frame(maxWidth: 500)
                    } else if let progress = task.progress {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(DesignSystem.success)
                            .frame(maxWidth: 500)
                    }

                    Text(task.sourceURL)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 10)

                if task.state == .completed {
                    Button("打开文件夹", systemImage: "folder", action: openFolder)
                        .buttonStyle(.borderless)
                }

                if task.state != .downloading {
                    Button("移除任务", systemImage: "xmark", action: removeTask)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .help("移除任务")
                }
            }
        }
    }

    private func openFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: model.outputDirectory))
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
        VStack(spacing: 12) {
            IconBadge(systemImage: systemImage, tint: .secondary, size: 52)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button(actionTitle, systemImage: "arrow.right", action: action)
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .padding(36)
        .frame(maxWidth: .infinity)
        .designCard()
    }
}
#endif
