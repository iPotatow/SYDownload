#if canImport(SwiftUI)
import SwiftUI
import AppKit

struct TasksView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
                HStack(alignment: .top) {
                    PageHeader(eyebrow: "DOWNLOAD QUEUE", title: "下载任务", subtitle: taskSummary, systemImage: "tray.full")
                    Spacer(minLength: 12)
                    Button("清空已完成", systemImage: "checkmark.circle", action: model.clearCompletedTasks)
                        .buttonStyle(.bordered)
                        .disabled(completedCount == 0)
                }

                MetricStrip(items: [
                    ("全部", "\(model.tasks.count)", "", "tray", DesignSystem.accent),
                    ("进行中", "\(activeCount)", "", "arrow.down.circle", DesignSystem.accent),
                    ("已完成", "\(completedCount)", "", "checkmark.circle", DesignSystem.success),
                    ("需处理", "\(failedCount)", "", "exclamationmark.triangle", DesignSystem.destructive)
                ])

                HStack {
                    Text("队列")
                        .font(DesignSystem.sectionTitleFont)
                    Text("\(model.filteredTasks.count) 项")
                        .font(DesignSystem.supportingFont)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("任务筛选", selection: $model.taskFilter) {
                        ForEach(TaskFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 110)
                }

                if model.filteredTasks.isEmpty {
                    EmptyLibraryView(
                        systemImage: "tray",
                        title: model.tasks.isEmpty ? "还没有下载任务" : "这个分类暂时为空",
                        message: model.tasks.isEmpty ? "粘贴链接并开始下载，任务会按状态显示在这里。" : "切换筛选条件，或开始一个新的下载。",
                        actionTitle: "新建下载"
                    ) { model.selection = .download }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(model.filteredTasks) { task in TaskRow(model: model, task: task) }
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
        .tint(DesignSystem.accent)
    }

    private var taskSummary: String {
        model.tasks.isEmpty ? "进行中的下载和完成状态会集中显示在这里。" : "当前显示 \(model.filteredTasks.count) 个任务，共 \(model.tasks.count) 个。"
    }
    private var activeCount: Int { model.tasks.filter { $0.state == .queued || $0.state == .downloading }.count }
    private var completedCount: Int { model.tasks.filter { $0.state == .completed }.count }
    private var failedCount: Int { model.tasks.filter { $0.state == .failed }.count }
}

private struct TaskRow: View {
    @ObservedObject var model: AppModel
    let task: DownloadTaskItem

    var body: some View {
        InsetRow {
            HStack(spacing: DesignSystem.spaceM) {
                PlatformThumbnail(platform: task.platform, size: 44)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: DesignSystem.spaceS) {
                        Text(task.title).font(.headline.weight(.semibold)).lineLimit(1)
                        StatusPill(state: task.state)
                    }
                    Text("\(task.platform.displayName) · \(task.detail)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    if task.state == .downloading || task.state == .queued {
                        ProgressView().progressViewStyle(.linear).tint(DesignSystem.accent).frame(maxWidth: 460)
                    } else if let progress = task.progress {
                        ProgressView(value: progress).progressViewStyle(.linear).tint(DesignSystem.success).frame(maxWidth: 460)
                    }
                    Text(task.sourceURL).font(.caption.monospaced()).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 8)
                if task.state == .completed {
                    Button("打开文件夹", systemImage: "folder", action: openFolder).buttonStyle(.borderless)
                }
                if task.state != .downloading {
                    Button("移除任务", systemImage: "xmark", action: removeTask)
                        .labelStyle(.iconOnly).buttonStyle(.borderless).help("移除任务")
                }
            }
        }
    }

    private func openFolder() { NSWorkspace.shared.open(URL(fileURLWithPath: model.outputDirectory)) }
    private func removeTask() { model.removeTask(task.id) }
}

struct EmptyLibraryView: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.spaceM) {
            IconBadge(systemImage: systemImage, tint: .secondary, size: 52)
            Text(title).font(.title3.weight(.semibold))
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 360)
            Button(actionTitle, systemImage: "arrow.right", action: action).buttonStyle(.borderedProminent)
        }
        .padding(DesignSystem.space2XL)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.rowBackground, in: RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous))
    }
}
#endif
