#if canImport(SwiftUI)
import SwiftUI
import AppKit

struct TasksView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("下载任务").font(.system(size: 28, weight: .bold))
                Spacer()
                Button("清空完成任务") { model.clearCompletedTasks() }
                    .disabled(!model.tasks.contains(where: { $0.state == .completed }))
            }

            Picker("任务筛选", selection: $model.taskFilter) {
                ForEach(TaskFilter.allCases) { filter in Text(filter.rawValue).tag(filter) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            if model.filteredTasks.isEmpty {
                EmptyLibraryView(systemImage: "tray", title: model.tasks.isEmpty ? "还没有下载任务" : "这个分类暂时为空", message: "粘贴链接并开始下载后，任务会显示在这里。", actionTitle: "新建下载") { model.selection = .download }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.filteredTasks) { task in TaskRow(model: model, task: task) }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: 900, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct TaskRow: View {
    @ObservedObject var model: AppModel
    let task: DownloadTaskItem

    var body: some View {
        HStack(spacing: 14) {
            PlatformThumbnail(platform: task.platform, size: 64)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(task.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    StatusPill(state: task.state)
                }
                HStack(spacing: 7) {
                    Text(task.platform.displayName)
                    Text("·")
                    Text(task.detail)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if task.state == .downloading || task.state == .queued {
                    ProgressView().progressViewStyle(.linear).frame(maxWidth: 420)
                } else if let progress = task.progress {
                    ProgressView(value: progress).progressViewStyle(.linear).frame(maxWidth: 420)
                }
            }
            Spacer(minLength: 16)
            if task.state == .completed {
                Button("打开文件夹") { NSWorkspace.shared.open(URL(fileURLWithPath: model.outputDirectory)) }.buttonStyle(.bordered)
            }
            if task.state != .downloading {
                Button { model.removeTask(task.id) } label: { Image(systemName: "xmark") }
                    .buttonStyle(.bordered)
                    .help("移除任务")
            }
        }
        .padding(12)
        .designCard()
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
            Image(systemName: systemImage).font(.system(size: 42, weight: .light)).foregroundStyle(.tertiary)
            Text(title).font(.title3.weight(.semibold))
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(actionTitle, action: action).buttonStyle(.borderedProminent)
        }
        .padding(40)
    }
}
#endif
