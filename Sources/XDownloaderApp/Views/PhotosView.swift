#if canImport(SwiftUI)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PhotosView: View {
    @State private var folderURL: URL?
    @State private var scanResult = PhotoScanResult.empty
    @State private var selectedDates: Set<String> = []
    @State private var showsFolderImporter = false
    @State private var showsDeleteConfirmation = false
    @State private var isDropTargeted = false
    @State private var isScanning = false
    @State private var isDeleting = false
    @State private var statusMessage = "拖入一个文件夹，或点击选择文件夹开始整理。"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            folderDropZone

            if isScanning {
                scanningState
            } else if folderURL == nil {
                emptyState
            } else {
                photoGroups
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .fileImporter(
            isPresented: $showsFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    openFolder(url)
                }
            case .failure(let error):
                statusMessage = error.localizedDescription
            }
        }
        .alert("删除所选日期的照片？", isPresented: $showsDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("移到废纸篓", role: .destructive) {
                deleteSelectedPhotos()
            }
        } message: {
            Text("将把 \(selectedPhotoURLs.count) 张照片从当前文件夹移到废纸篓。")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("照片")
                    .font(.system(size: 26, weight: .semibold))
                Text("按文件名中的日期分组，选择一个或多个日期后批量删除。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if folderURL != nil {
                Button {
                    if let folderURL {
                        openFolder(folderURL)
                    }
                } label: {
                    Label("重新扫描", systemImage: "arrow.clockwise")
                }
                .disabled(isScanning || isDeleting)
            }

            Button {
                showsFolderImporter = true
            } label: {
                Label("选择文件夹", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isScanning || isDeleting)
        }
    }

    private var folderDropZone: some View {
        VStack(spacing: 9) {
            Image(systemName: isDropTargeted ? "folder.fill.badge.plus" : "folder.badge.plus")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)

            if let folderURL {
                Text(folderURL.lastPathComponent)
                    .font(.headline)
                Text(folderURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("拖拽图片文件夹到这里")
                    .font(.headline)
                Text("会递归读取子文件夹中的图片")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 92)
        .padding(.horizontal, 20)
        .background(
            isDropTargeted ? Color.accentColor.opacity(0.09) : Color.primary.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.08),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 5])
                )
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let folder = urls.first(where: isDirectory) else {
                statusMessage = "请拖入文件夹，而不是单个文件。"
                return false
            }
            openFolder(folder)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }

    private var scanningState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("正在读取图片并解析文件名日期…")
                .font(.headline)
            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text("还没有读取照片")
                .font(.title3.weight(.semibold))
            Text("支持 2026-09-07、2026_09_07、2026.09.07、20260907、2026年09月07日 等日期格式。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var photoGroups: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryBar

            if scanResult.totalCount == 0 {
                ContentUnavailableView(
                    "没有找到图片",
                    systemImage: "photo.slash",
                    description: Text("请选择包含图片的文件夹。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(scanResult.groups) { group in
                            dateGroupRow(group)
                        }

                        if !scanResult.ungrouped.isEmpty {
                            ungroupedRow
                        }
                    }
                    .padding(.bottom, selectedDates.isEmpty ? 8 : 72)
                }
                .overlay(alignment: .bottom) {
                    if !selectedDates.isEmpty {
                        deleteBar
                    }
                }
            }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 12) {
            Label("\(scanResult.totalCount) 张照片", systemImage: "photo.stack")
            Text("·")
                .foregroundStyle(.tertiary)
            Text("\(scanResult.groups.count) 个日期")
                .foregroundStyle(.secondary)

            if !scanResult.ungrouped.isEmpty {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("\(scanResult.ungrouped.count) 张未识别日期")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !scanResult.groups.isEmpty {
                Button(allDatesSelected ? "取消全选" : "全选日期") {
                    if allDatesSelected {
                        selectedDates.removeAll()
                    } else {
                        selectedDates = Set(scanResult.groups.map(\.id))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
            }
        }
        .font(.subheadline)
    }

    private func dateGroupRow(_ group: PhotoDateGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Toggle(
                    isOn: Binding(
                        get: { selectedDates.contains(group.id) },
                        set: { selected in
                            if selected {
                                selectedDates.insert(group.id)
                            } else {
                                selectedDates.remove(group.id)
                            }
                        }
                    )
                ) {
                    Text(group.dateKey)
                        .font(.headline)
                }
                .toggleStyle(.checkbox)

                Spacer()

                Text("\(group.photos.count) 张")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            thumbnailStrip(group.photos)
        }
        .padding(14)
        .background(
            selectedDates.contains(group.id) ? Color.accentColor.opacity(0.07) : Color.primary.opacity(0.03),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    selectedDates.contains(group.id) ? Color.accentColor.opacity(0.28) : Color.primary.opacity(0.05)
                )
        }
    }

    private var ungroupedRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("未识别日期", systemImage: "questionmark.circle")
                    .font(.headline)
                Spacer()
                Text("\(scanResult.ungrouped.count) 张 · 不参与日期批量删除")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            thumbnailStrip(scanResult.ungrouped)
        }
        .padding(14)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func thumbnailStrip(_ photos: [PhotoFileItem]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(photos.prefix(8))) { photo in
                    LocalPhotoThumbnail(url: photo.url)
                }

                if photos.count > 8 {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                        Text("+\(photos.count - 8)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 68, height: 68)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var deleteBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("已选择 \(selectedDates.count) 个日期")
                    .font(.subheadline.weight(.semibold))
                Text("共 \(selectedPhotoURLs.count) 张照片")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("取消选择") {
                selectedDates.removeAll()
            }
            .disabled(isDeleting)

            Button(role: .destructive) {
                showsDeleteConfirmation = true
            } label: {
                if isDeleting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("删除 \(selectedPhotoURLs.count) 张照片", systemImage: "trash")
                }
            }
            .disabled(isDeleting || selectedPhotoURLs.isEmpty)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .shadow(radius: 8, y: 3)
    }

    private var selectedPhotoURLs: [URL] {
        scanResult.groups
            .filter { selectedDates.contains($0.id) }
            .flatMap { $0.photos.map(\.url) }
    }

    private var allDatesSelected: Bool {
        !scanResult.groups.isEmpty && selectedDates.count == scanResult.groups.count
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    @MainActor
    private func openFolder(_ url: URL, statusPrefix: String? = nil) {
        folderURL = url
        selectedDates.removeAll()
        isScanning = true
        statusMessage = "正在扫描 \(url.lastPathComponent)…"

        Task {
            let outcome = await Task.detached(priority: .userInitiated) {
                do {
                    return PhotoScanOutcome.success(try PhotoLibraryService.scan(folder: url))
                } catch {
                    return PhotoScanOutcome.failure(error.localizedDescription)
                }
            }.value

            isScanning = false
            switch outcome {
            case .success(let result):
                scanResult = result
                let summary = "读取到 \(result.totalCount) 张照片，其中 \(result.recognizedCount) 张已按日期分组。"
                if let statusPrefix {
                    statusMessage = "\(statusPrefix) \(summary)"
                } else {
                    statusMessage = summary
                }
            case .failure(let message):
                scanResult = .empty
                statusMessage = message
            }
        }
    }

    @MainActor
    private func deleteSelectedPhotos() {
        let urls = selectedPhotoURLs
        guard !urls.isEmpty else { return }

        isDeleting = true
        statusMessage = "正在删除所选照片…"

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                PhotoLibraryService.moveToTrash(urls)
            }.value

            isDeleting = false
            let failedText = result.failedPaths.isEmpty ? "" : " \(result.failedPaths.count) 张删除失败。"
            let prefix = "已移到废纸篓 \(result.deletedCount) 张照片。\(failedText)"

            if let folderURL {
                openFolder(folderURL, statusPrefix: prefix)
            } else {
                statusMessage = prefix
            }
        }
    }
}

private struct LocalPhotoThumbnail: View {
    let url: URL

    var body: some View {
        Group {
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.primary.opacity(0.04)
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 68, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07))
        }
        .help(url.lastPathComponent)
    }
}
#endif
