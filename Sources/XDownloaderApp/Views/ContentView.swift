#if canImport(SwiftUI)
import SwiftUI
import XDownloaderCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            List {
                Label("下载", systemImage: "arrow.down.circle.fill")
                    .fontWeight(.semibold)
                Label("任务", systemImage: "tray.full")
                Label("历史记录", systemImage: "clock")
                Divider()
                Label("小红书", systemImage: "photo.on.rectangle")
                Label("抖音 / TikTok", systemImage: "play.rectangle")
                Divider()
                Label("设置", systemImage: "gearshape")
            }
            .listStyle(.sidebar)
            .navigationTitle("XDownloader")
        } detail: {
            VStack(alignment: .leading, spacing: 18) {
                Text("下载")
                    .font(.largeTitle.bold())

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        TextEditor(text: $model.input)
                            .font(.body)
                            .frame(minHeight: 110)
                            .overlay(alignment: .topLeading) {
                                if model.input.isEmpty {
                                    Text("粘贴小红书 / 抖音 / TikTok 链接")
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                            }

                        HStack {
                            platformBadge
                            Spacer()
                            Button("验证引擎") {
                                Task { await model.validateEngine() }
                            }
                            .disabled(model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isWorking)
                        }
                    }
                    .padding(4)
                }

                GroupBox("保存位置") {
                    HStack {
                        TextField("下载目录", text: $model.outputDirectory)
                        Button("Downloads") {
                            if let path = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path {
                                model.outputDirectory = path
                            }
                        }
                    }
                    .padding(4)
                }

                GroupBox("可行性验证状态") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            if model.isWorking { ProgressView().controlSize(.small) }
                            Text(model.status)
                        }
                        ForEach(model.lastDetails.keys.sorted(), id: \.self) { key in
                            LabeledContent(key, value: model.lastDetails[key] ?? "")
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }

                Spacer()

                Button {
                    Task { await model.runDownload() }
                } label: {
                    Text(model.isWorking ? "处理中…" : "开始下载")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.detectedPlatform == .unknown || model.isWorking)
            }
            .padding(24)
            .frame(minWidth: 720, minHeight: 520)
            .onChange(of: model.input) { _, _ in model.detectLocally() }
        }
    }

    @ViewBuilder
    private var platformBadge: some View {
        let p = model.detectedPlatform
        HStack(spacing: 6) {
            Image(systemName: p == .unknown ? "questionmark.circle" : "checkmark.circle.fill")
            Text(p.displayName)
        }
        .foregroundStyle(p == .unknown ? .secondary : .primary)
    }
}
#endif
