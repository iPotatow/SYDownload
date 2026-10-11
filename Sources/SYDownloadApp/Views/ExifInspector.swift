#if canImport(SwiftUI)
import SwiftUI

struct ExifInspector: View {
    @ObservedObject var model: ExifEditorModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("处理规则").font(CoreTypography.sectionTitleFont)
                group("时间", systemImage: "clock") {
                    Toggle("从文件名恢复时间", isOn: $model.options.writeDates)
                    if model.options.writeDates {
                        Picker("秒数来源", selection: $model.options.secondsSource) {
                            ForEach(ExifSecondsSource.allCases) { Text($0.rawValue).tag($0) }
                        }.labelsHidden().accessibilityLabel("秒数来源")
                        note("YYYY-MM-DD_HH.mm.ss_编号\n更新拍摄、EXIF 创建和元数据修改时间。")
                    }
                }
                Divider()
                group("格式", systemImage: "photo") {
                    Toggle("PNG 转为 JPEG", isOn: $model.options.convertPNG)
                    if model.options.convertPNG {
                        HStack {
                            Text("JPEG 质量")
                            Spacer()
                            Text("\(Int(model.options.jpegQuality * 100))%").monospacedDigit()
                        }.font(CoreTypography.captionFont).foregroundStyle(CoreColor.textSecondary)
                        Slider(value: $model.options.jpegQuality, in: 0.5...1, step: 0.05).accessibilityLabel("JPEG 质量")
                        note("有损转换，透明区域填充白色。")
                    } else { note("保留原格式和图片尺寸。") }
                }
                Divider()
                group("相机", systemImage: "camera") {
                    Toggle("修改品牌与型号", isOn: $model.options.writeCamera)
                    if model.options.writeCamera {
                        TextField("品牌", text: $model.options.make).textFieldStyle(.roundedBorder)
                            .accessibilityLabel("相机品牌")
                        TextField("型号", text: $model.options.model).textFieldStyle(.roundedBorder)
                            .accessibilityLabel("相机型号")
                    } else { note("保留原始相机信息。") }
                }
                Divider()
                group("保存", systemImage: "folder") {
                    Picker("保存方式", selection: $model.options.saveMode) {
                        Text("保留原图，另存结果").tag(ExifSaveMode.copies)
                        Text("备份后替换原图").tag(ExifSaveMode.replaceWithBackup)
                    }.labelsHidden().accessibilityLabel("保存方式")
                    Label(model.options.saveMode == .copies ? "原图保留" : "原图自动备份", systemImage: "doc.on.doc")
                        .font(CoreTypography.groupLabelFont).foregroundStyle(CoreColor.accent)
                    note(model.options.saveMode == .copies ? "保存到“EXIF 输出”文件夹。\n已有同名结果自动跳过。" : "每批创建独立备份文件夹，处理成功后替换原图。")
                }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(CoreColor.panelBackground, in: RoundedRectangle(cornerRadius: CoreRadius.panel))
        .disabled(model.processing)
        .font(CoreTypography.bodyFont)
        .controlSize(.regular)
    }

    private func group<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage).font(CoreTypography.groupLabelFont)
                .foregroundStyle(CoreColor.textSecondary)
            content()
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(CoreTypography.captionFont).foregroundStyle(CoreColor.textSecondary)
            .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
    }
}
#endif
