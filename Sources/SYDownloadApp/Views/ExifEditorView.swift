#if canImport(SwiftUI)
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ExifEditorView: View {
    @ObservedObject var model: ExifEditorModel
    @State private var importing = false
    @State private var confirming = false
    @State private var dropTargeted = false

    var body: some View {
        CorePageContainer(title: "EXIF 编辑", maxWidth: SYDownloadLayout.contentMaxWidth) {
            Button("选择文件夹", systemImage: "folder") { importing = true }
                .coreAction()
                .disabled(model.busy)
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                folderBar
                HStack(alignment: .top, spacing: 20) {
                    VStack(spacing: 16) {
                        if model.plans.isEmpty { emptyState }
                        else {
                            ExifFileTable(model: model)
                            if let plan = model.activePlan {
                                ExifChangePreview(plan: plan, options: model.options)
                            }
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    ExifInspector(model: model).frame(width: 248)
                }.frame(maxHeight: .infinity)
                footer
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { model.open(url) }
            if case .failure(let error) = result { model.reportImportFailure(error.localizedDescription) }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first, !model.busy else { return false }
            model.open(url); return true
        } isTargeted: { dropTargeted = $0 }
        .onChange(of: model.options) { _, _ in model.refresh() }
        .alert("备份并替换原图？", isPresented: $confirming) {
            Button("取消", role: .cancel) {}
            Button("备份并处理", role: .destructive) { model.run() }
        } message: {
            Text("原图将备份到当前文件夹内独立的 EXIF 备份文件夹，再替换。启用格式转换时，原 PNG 会在 JPEG 验证并保存成功后移除。")
        }
    }

    private var folderBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder").font(.system(size: 19, weight: .light))
                .foregroundStyle(CoreColor.textSecondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.folder?.lastPathComponent ?? "尚未选择文件夹")
                    .font(CoreTypography.controlFont)
                Text(model.folder?.path ?? "支持 JPG、JPEG、PNG，只处理当前文件夹")
                    .font(CoreTypography.captionFont).foregroundStyle(CoreColor.textSecondary)
                    .lineLimit(1).truncationMode(.middle).help(model.folder?.path ?? "")
            }
            Spacer(minLength: 0)
            if model.folder != nil {
                Button("重新读取", systemImage: "arrow.clockwise") { model.refresh() }
                    .coreAction(.tertiary).disabled(model.busy)
                Text("\(model.plans.count) 张照片").font(CoreTypography.captionFont).monospacedDigit()
                    .foregroundStyle(CoreColor.textSecondary)
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 14)
        .background(CoreColor.panelBackground, in: RoundedRectangle(cornerRadius: CoreRadius.panel))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 34, weight: .ultraLight)).foregroundStyle(CoreColor.textTertiary)
                .padding(.bottom, 6)
            Text(model.busy ? "正在读取照片" : "整理照片里的时间信息")
                .font(CoreTypography.sectionTitleFont)
            Text(model.folder == nil ? "拖入文件夹，先预览每张照片的改动。\n默认保留原图，处理结果另存。" : model.status)
                .font(CoreTypography.bodyFont).foregroundStyle(CoreColor.textSecondary)
                .multilineTextAlignment(.center).lineSpacing(4).frame(maxWidth: 280)
            Button("选择文件夹") { importing = true }.coreAction(.primary).disabled(model.busy).padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(dropTargeted ? CoreColor.selectionBackground : .clear, in: RoundedRectangle(cornerRadius: CoreRadius.panel))
        .overlay {
            RoundedRectangle(cornerRadius: CoreRadius.panel)
                .strokeBorder(dropTargeted ? CoreColor.accent : CoreColor.divider, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Divider()
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.processing ? "正在处理 · \(model.completed) / \(model.total)" : "已选择 \(model.readyCount) 张照片")
                        .font(CoreTypography.controlFont).monospacedDigit()
                    Text(model.status).font(CoreTypography.captionFont).foregroundStyle(CoreColor.textSecondary)
                        .lineLimit(1).help(model.status)
                }
                Spacer(minLength: 8)
                if model.busy { Button("取消") { model.cancel() }.coreAction() }
                else {
                    if let folder = model.resultFolder {
                        Button("打开结果", systemImage: "arrow.up.forward.square") {
                            NSWorkspace.shared.open(folder)
                        }.coreAction()
                    }
                    Button("开始处理", systemImage: "arrow.right") {
                        if model.options.saveMode == .replaceWithBackup { confirming = true }
                        else { model.run() }
                    }
                    .coreAction(.primary)
                    .disabled(!model.canRun)
                }
            }
            if model.processing {
                ProgressView(value: Double(model.completed), total: Double(max(1, model.total)))
            }
        }
    }
}
#endif
