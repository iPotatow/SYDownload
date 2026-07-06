#if canImport(SwiftUI)
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ImageIO

struct PhotosView: View {
    @State private var folderURL: URL?
    @State private var scanResult = PhotoScanResult.empty
    @State private var selectedDates: Set<String> = []
    @State private var showsFolderImporter = false
    @State private var showsDeleteConfirmation = false
    @State private var isDropTargeted = false
    @State private var isScanning = false
    @State private var isDeleting = false
    @State private var statusIsError = false
    @State private var statusMessage = "拖入一个文件夹，或点击选择文件夹开始整理。"

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
            header
            workspace
            if !statusMessage.isEmpty && !isScanning {
                Label(statusMessage, systemImage: statusIsError ? "exclamationmark.circle" : "info.circle")
                    .font(.callout)
                    .foregroundStyle(statusIsError ? DesignSystem.destructive : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, DesignSystem.contentPadding)
        .padding(.top, DesignSystem.contentPadding)
        .padding(.bottom, DesignSystem.space3XL)
        .frame(maxWidth: DesignSystem.pageMaxWidth, alignment: .leading)
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
                statusIsError = true
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
        .tint(DesignSystem.accent)
    }

    private var header: some View {
        PageHeader(
            title: "照片整理",
            subtitle: "按文件名中的日期分组，预览后再选择需要处理的日期。"
        )
    }

    @ViewBuilder
    private var workspace: some View {
        if folderURL == nil && !isScanning {
            initialDropZone
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isScanning {
            scanningState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            photoGroups
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var initialDropZone: some View {
        VStack(spacing: DesignSystem.spaceM) {
            Image(systemName: isDropTargeted ? "folder.fill.badge.plus" : "folder")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(isDropTargeted ? DesignSystem.accent : Color.secondary)

            Text("拖入照片文件夹到这里")
                .font(.title3.weight(.semibold))

            Text("会读取文件夹中的图片并按文件名日期分组")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("或")
                .font(.callout)
                .foregroundStyle(.tertiary)

            Button("选择文件夹…", systemImage: "folder", action: chooseFolder)
                .buttonStyle(.borderedProminent)

            Text("支持 JPG、PNG、HEIC 等常见图片格式")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, DesignSystem.spaceS)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .background(
            isDropTargeted ? DesignSystem.accent.opacity(0.06) : Color.clear,
            in: RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? DesignSystem.accent.opacity(0.65) : DesignSystem.hairline,
                    style: StrokeStyle(lineWidth: 1, dash: [8, 4])
                )
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let folder = urls.first(where: isDirectory) else {
                statusMessage = "请拖入文件夹，而不是单个文件。"
                statusIsError = true
                return false
            }
            openFolder(folder)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }

    private var scanningState: some View {
        VStack(spacing: DesignSystem.spaceM) {
            ProgressView()
                .controlSize(.large)
                .tint(DesignSystem.accent)
            Text("正在读取图片并解析文件名日期…")
                .font(.headline)
            Text(statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private var photoGroups: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceM) {
            summaryBar
            Divider()

            if scanResult.totalCount == 0 {
                ContentUnavailableView(
                    "没有找到图片",
                    systemImage: "photo.slash",
                    description: Text("请选择包含图片的文件夹。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.spaceS) {
                        ForEach(scanResult.groups) { group in
                            dateGroupRow(group)
                        }

                        if !scanResult.ungrouped.isEmpty {
                            ungroupedRow
                        }
                    }
                    .padding(.bottom, selectedDates.isEmpty ? DesignSystem.spaceS : 76)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !selectedDates.isEmpty {
                        deleteBar
                    }
                }
            }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: DesignSystem.spaceM) {
            if let folderURL {
                Label(folderURL.lastPathComponent, systemImage: "folder")
                    .font(.callout.weight(.semibold))
                    .help(folderURL.path)
            }

            Text("\(scanResult.totalCount) 张照片")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("\(scanResult.groups.count) 个日期")
                .font(.callout)
                .foregroundStyle(.secondary)

            if !scanResult.ungrouped.isEmpty {
                Text("\(scanResult.ungrouped.count) 张未识别日期")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !scanResult.groups.isEmpty {
                Button(
                    allDatesSelected ? "取消全选" : "全选日期",
                    systemImage: allDatesSelected ? "minus.square" : "checkmark.square",
                    action: toggleAllDates
                )
                .buttonStyle(.borderless)
                .disabled(isDeleting)
            }
        }
    }

    private func dateGroupRow(_ group: PhotoDateGroup) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceM) {
            HStack(spacing: DesignSystem.spaceS) {
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
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            thumbnailStrip(group.photos)
        }
        .padding(DesignSystem.panelPadding)
        .background(
            selectedDates.contains(group.id) ? DesignSystem.accentTint : DesignSystem.rowBackground,
            in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
                .strokeBorder(
                    selectedDates.contains(group.id) ? DesignSystem.accent.opacity(0.30) : Color.clear
                )
        }
    }

    private var ungroupedRow: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceM) {
            HStack {
                Label("未识别日期", systemImage: "questionmark.circle")
                    .font(.headline)
                Spacer()
                Text("\(scanResult.ungrouped.count) 张 · 不参与日期批量删除")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            thumbnailStrip(scanResult.ungrouped)
        }
        .padding(DesignSystem.panelPadding)
        .background(
            DesignSystem.rowBackground,
            in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
        )
    }

    private func thumbnailStrip(_ photos: [PhotoFileItem]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: DesignSystem.spaceS) {
                ForEach(Array(photos.prefix(8))) { photo in
                    LocalPhotoThumbnail(url: photo.url)
                }

                if photos.count > 8 {
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
                            .fill(DesignSystem.raisedSurface)
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
        HStack(spacing: DesignSystem.spaceM) {
            VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
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
        .padding(DesignSystem.panelPadding)
        .background(
            DesignSystem.panelBackground,
            in: RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous)
                .strokeBorder(DesignSystem.hairline)
        }
        .padding(.horizontal, DesignSystem.spaceS)
        .padding(.bottom, DesignSystem.spaceS)
        .shadow(color: DesignSystem.shadow, radius: DesignSystem.spaceS, y: DesignSystem.spaceXS)
    }

    private var selectedPhotoURLs: [URL] {
        scanResult.groups
            .filter { selectedDates.contains($0.id) }
            .flatMap { $0.photos.map(\.url) }
    }

    private var allDatesSelected: Bool {
        !scanResult.groups.isEmpty && selectedDates.count == scanResult.groups.count
    }

    private func chooseFolder() {
        showsFolderImporter = true
    }

    private func rescan() {
        guard let folderURL else { return }
        openFolder(folderURL)
    }

    private func toggleAllDates() {
        if allDatesSelected {
            selectedDates.removeAll()
        } else {
            selectedDates = Set(scanResult.groups.map(\.id))
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    @MainActor
    private func openFolder(_ url: URL, statusPrefix: String? = nil) {
        folderURL = url
        selectedDates.removeAll()
        isScanning = true
        statusIsError = statusPrefix?.contains("失败") == true
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
                statusIsError = true
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
            statusIsError = !result.failedPaths.isEmpty
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
            if let image = thumbnailImage {
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
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07))
        }
        .help(url.lastPathComponent)
        .accessibilityLabel(url.lastPathComponent)
    }

    private var thumbnailImage: NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 136,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ] as CFDictionary
              ) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: 68, height: 68))
    }
}
#endif
