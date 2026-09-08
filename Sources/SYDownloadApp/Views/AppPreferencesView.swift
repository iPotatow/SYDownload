#if canImport(SwiftUI)
import AppKit
import SwiftUI

struct AppPreferencesView: View {
    @ObservedObject var model: AppModel
    @AppStorage("preferredAppearance") private var preferredAppearance = "跟随系统"

    var body: some View {
        Form {
            Section("保存位置") {
                LabeledContent("默认下载目录") {
                    HStack(spacing: DesignSystem.spaceS) {
                        TextField("下载目录", text: $model.outputDirectory)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 280)
                        Button("选择…", action: chooseFolder)
                    }
                }

                Text("新建下载会使用这里的目录；已有任务继续使用创建任务时记录的位置。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("外观") {
                LabeledContent("应用外观") {
                    Picker("应用外观", selection: $preferredAppearance) {
                        ForEach(["跟随系统", "浅色", "深色"], id: \.self) { value in
                            Text(value).tag(value)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
            }
        }
        .formStyle(.grouped)
        .padding(DesignSystem.spaceL)
        .preferredColorScheme(
            preferredAppearance == "浅色" ? .light : preferredAppearance == "深色" ? .dark : nil
        )
        .tint(DesignSystem.accent)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择默认下载目录"
        panel.prompt = "选择"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            model.outputDirectory = url.path
        }
    }
}
#endif
