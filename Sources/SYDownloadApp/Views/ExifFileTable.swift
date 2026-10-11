#if canImport(SwiftUI)
import SwiftUI

struct ExifFileTable: View {
    @ObservedObject var model: ExifEditorModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("照片").font(CoreTypography.sectionTitleFont)
                Spacer()
                Button(model.selected.isEmpty ? "全选" : "取消全选") {
                    model.selected = model.selected.isEmpty ? Set(model.plans.filter { $0.issue == nil }.map(\.id)) : []
                }.coreAction(.tertiary).disabled(model.busy)
            }.padding(.horizontal, 12).padding(.vertical, 10)
            Divider()
            Table(model.plans, selection: $model.active) {
                TableColumn("") { plan in
                    Toggle("选择 \(plan.source.lastPathComponent)", isOn: Binding(
                        get: { model.selected.contains(plan.id) },
                        set: { if $0 { model.selected.insert(plan.id) } else { model.selected.remove(plan.id) } }
                    )).labelsHidden().toggleStyle(.checkbox).disabled(model.busy || plan.issue != nil)
                }.width(22)
                TableColumn("文件") { plan in
                    HStack(spacing: 8) {
                        Text(plan.source.pathExtension.uppercased())
                            .font(CoreTypography.groupLabelFont)
                            .foregroundStyle(CoreColor.textSecondary)
                            .frame(width: 40, height: 32)
                            .background(CoreColor.panelBackground, in: RoundedRectangle(cornerRadius: 4))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(plan.source.lastPathComponent).font(CoreTypography.bodyFont)
                                .lineLimit(1).truncationMode(.middle)
                            Text(plan.convertsPNG ? "转换为 JPEG" : ByteCountFormatter.string(fromByteCount: Int64(plan.fileSize), countStyle: .file))
                                .font(CoreTypography.captionFont).foregroundStyle(CoreColor.textSecondary)
                        }
                    }.padding(.vertical, 5).help(plan.source.lastPathComponent)
                }.width(min: 155, ideal: 210)
                TableColumn("拟写入时间 / 状态") { plan in
                    Text(model.outcomes[plan.id]?.label ?? plan.issue ?? plan.timestamp ?? "保持时间")
                        .font(CoreTypography.captionFont).monospacedDigit()
                        .foregroundStyle(statusColor(plan)).lineLimit(2)
                        .help(model.outcomes[plan.id]?.label ?? plan.issue ?? plan.timestamp ?? "保持时间")
                }.width(min: 125, ideal: 145)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, minHeight: 180, maxHeight: .infinity)
        .background(CoreColor.contentBackground)
        .clipShape(RoundedRectangle(cornerRadius: CoreRadius.panel))
        .overlay { RoundedRectangle(cornerRadius: CoreRadius.panel).strokeBorder(CoreColor.divider, lineWidth: 0.5) }
    }

    private func statusColor(_ plan: ExifFilePlan) -> Color {
        if let outcome = model.outcomes[plan.id] {
            switch outcome {
            case .success: return CoreColor.success
            case .failure: return CoreColor.danger
            case .skipped, .cancelled: return CoreColor.textSecondary
            }
        }
        return plan.issue == nil ? CoreColor.textSecondary : CoreColor.warning
    }
}

struct ExifChangePreview: View {
    let plan: ExifFilePlan
    let options: ExifProcessingOptions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("改动对照").font(CoreTypography.sectionTitleFont)
                Spacer()
                Text(plan.source.lastPathComponent).font(CoreTypography.captionFont)
                    .foregroundStyle(CoreColor.textSecondary).lineLimit(1).truncationMode(.middle)
            }
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 9) {
                GridRow {
                    Text("")
                    Text("原始信息").foregroundStyle(CoreColor.textTertiary)
                    Text("处理后").foregroundStyle(CoreColor.textTertiary)
                }
                changeRow("拍摄时间", before: plan.originalDate, after: options.writeDates ? plan.timestamp ?? "文件名无效" : "保持原值")
                changeRow("EXIF 创建", before: plan.originalCreateDate, after: options.writeDates ? plan.timestamp ?? "文件名无效" : "保持原值")
                changeRow("元数据修改", before: plan.originalModifyDate, after: options.writeDates ? plan.timestamp ?? "文件名无效" : "保持原值")
                changeRow("相机", before: plan.originalCamera, after: options.writeCamera ? "\(options.make) / \(options.model)" : "保持原值")
                changeRow("文件", before: plan.source.lastPathComponent, after: plan.targetName)
            }.font(CoreTypography.captionFont).frame(maxWidth: .infinity, alignment: .leading)
            Text(options.saveMode == .copies ? "保存到：EXIF 输出/\(plan.targetName)" : "备份原图后保存到：\(plan.targetName)")
                .font(CoreTypography.captionFont).foregroundStyle(CoreColor.textSecondary)
                .textSelection(.enabled)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(CoreColor.panelBackground, in: RoundedRectangle(cornerRadius: CoreRadius.panel))
    }

    private func changeRow(_ title: String, before: String, after: String) -> some View {
        GridRow(alignment: .top) {
            Text(title).foregroundStyle(CoreColor.textSecondary)
            Text(before).foregroundStyle(CoreColor.textSecondary).textSelection(.enabled).help(before)
            Text(after).foregroundStyle(CoreColor.textPrimary).textSelection(.enabled).help(after)
        }
    }
}
#endif
