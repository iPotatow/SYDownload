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
    @State private var statusMessage = ""

    var body: some View {
        PageContainer(title: "照片整理") {
            VStack(alignment: .leading, spacing: DesignSystem.spaceL) {
                workspace

                if shouldShowStatus {
                    Label(
                        statusMessage,
                        systemImage: statusIsError ? "exclamationmark.circle" : "checkmark.circle"
                    )
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(statusIsError ? DesignSystem.destructive : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
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
                statusMessage = "无法打开文件夹：\(error.localizedDescription)"
                statusIsError = true
            }
        }
        .alert("将所选照片移到废纸篓？", isPresented: $showsDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("移到废纸篓", role: .destructive) {
                deleteSelectedPhotos()
            }
        } message: {
            Text("将把 \(selectedPhotoURLs.count) 张照片从当前文件夹移到废纸篓。")
        }
        .tint(DesignSystem.accent)
    }

    private var shouldShowStatus: Bool {
        !statusMessage.isEmpty && !isScanning
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
                .font(.system(size: DesignSystem.controlHeightLarge, weight: .regular))
                .foregroundStyle(isDropTargeted ? DesignSystem.accent : Color.secondary)

            Text("拖入照片文件夹到这里")
                .font(DesignSystem.sectionTitleFont)

            Text("会读取文件夹中的图片并按文件名日期分组")
                .font(DesignSystem.bodyFont)
                .foregroundStyle(.secondary)

            Button("选择文件夹…", systemImage: "folder", action: chooseFolder)
                .buttonStyle(.borderedProminent)
                .font(DesignSystem.uiFont)
                .frame(height: DesignSystem.controlHeightDefault)

            Text("支持 JPG、PNG、HEIC 等常见图片格式")
                .font(DesignSystem.metadataFont)
                .foregroundStyle(.tertiary)
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
                    style: StrokeStyle(lineWidth: DesignSystem.borderWidth, dash: [8, 4])
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
                .font(DesignSystem.sectionTitleFont)
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private var photoGroups: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spaceM) {
            summaryBar
            Divider()

            if scanResult.totalCount == 0 {
                EmptyLibraryView(
                    systemImage: "photo.slash",
                    title: "没有找到图片",
                    message: "请选择包含 JPG、PNG 或 HEIC 图片的文件夹。",
                    actionTitle: "更换文件夹"
                ) {
                    chooseFolder()
                }
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
                    .padding(.bottom, selectedDates.isEmpty ? DesignSystem.spaceS : 64)
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
        VStack(alignment: .leading, spacing: DesignSystem.spaceS) {
            HStack(spacing: DesignSystem.spaceS) {
                if let folderURL {
                    Label(folderURL.path, systemImage: "folder")
                        .font(DesignSystem.bodyFont)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(folderURL.path)
                }

                Spacer(minLength: DesignSystem.spaceM)

                Button("重新扫描", systemImage: "arrow.clockwise", action: rescan)
                    .buttonStyle(.borderless)
                    .font(DesignSystem.uiFont)
                    .frame(height: DesignSystem.controlHeightCompact)
                    .disabled(isDeleting || isScanning)

                Button("更换文件夹…", systemImage: "folder", action: chooseFolder)
                    .buttonStyle(.bordered)
                    .font(DesignSystem.uiFont)
                    .frame(height: DesignSystem.controlHeightCompact)
                    .disabled(isDeleting || isScanning)
            }

            HStack(spacing: DesignSystem.spaceM) {
                Text("\(scanResult.totalCount) 张照片")
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(.secondary)
                Text("\(scanResult.groups.count) 个日期")
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(.secondary)

                if !scanResult.ungrouped.isEmpty {
                    Text("\(scanResult.ungrouped.count) 张未识别日期")
                        .font(DesignSystem.bodyFont)
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
                    .font(DesignSystem.uiFont)
                    .frame(height: DesignSystem.controlHeightCompact)
                    .disabled(isDeleting)
                }
            }
        }
        .frame(minHeight: DesignSystem.controlRowMinHeight)
    }

    private func dateGroupRow(_ group: PhotoDateGroup) -> some View {
        HStack(spacing: DesignSystem.spaceM) {
            Toggle(
                "选择 \(group.dateKey)",
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
            )
            .labelsHidden()
            .toggleStyle(.checkbox)

            VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                Text(group.dateKey)
                    .font(DesignSystem.uiFont)
                Text("\(group.photos.count) 张照片")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 104, alignment: .leading)

            thumbnailStrip(group.photos)

            Spacer(minLength: 0)
        }
        .padding(DesignSystem.spaceM)
        .background(
            selectedDates.contains(group.id) ? DesignSystem.accentTint : DesignSystem.rowBackground,
            in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
                .strokeBorder(
                    selectedDates.contains(group.id) ? DesignSystem.accent.opacity(0.30) : DesignSystem.hairline,
                    lineWidth: DesignSystem.borderWidth
                )
        }
    }

    private var ungroupedRow: some View {
        HStack(spacing: DesignSystem.spaceM) {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
                .frame(width: DesignSystem.spaceL)

            VStack(alignment: .leading, spacing: DesignSystem.spaceXS) {
                Text("未识别日期")
                    .font(DesignSystem.uiFont)
                Text("\(scanResult.ungrouped.count) 张照片 · 不参与批量删除")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 160, alignment: .leading)

            thumbnailStrip(scanResult.ungrouped)
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.spaceM)
        .background(
            DesignSystem.rowBackground,
            in: RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.rowRadius, style: .continuous)
                .strokeBorder(DesignSystem.hairline, lineWidth: DesignSystem.borderWidth)
        }
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
                            .font(DesignSystem.groupLabelFont)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: DesignSystem.photoThumbnailSize, height: DesignSystem.photoThumbnailSize)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var deleteBar: some View {
        HStack(spacing: DesignSystem.spaceM) {
            Text("已选择 \(selectedDates.count) 个日期 · \(selectedPhotoURLs.count) 张照片")
                .font(DesignSystem.uiFont)
                .monospacedDigit()

            Spacer()

            Button("取消选择") {
                selectedDates.removeAll()
            }
            .font(DesignSystem.uiFont)
            .frame(height: DesignSystem.controlHeightDefault)
            .disabled(isDeleting)

            Button(role: .destructive) {
                showsDeleteConfirmation = true
            } label: {
                if isDeleting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("移到废纸篓", systemImage: "trash")
                }
            }
            .font(DesignSystem.uiFont)
            .frame(height: DesignSystem.controlHeightDefault)
            .disabled(isDeleting || selectedPhotoURLs.isEmpty)
        }
        .padding(.horizontal, DesignSystem.panelPadding)
        .padding(.vertical, DesignSystem.spaceS)
        .background(DesignSystem.mainSurfaceBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignSystem.hairline)
                .frame(height: DesignSystem.dividerWidth)
        }
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
        statusIsError = false
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
                statusIsError = false
                statusMessage = statusPrefix ?? ""
            case .failure(let message):
                scanResult = .empty
                statusMessage = "无法读取照片：\(message)"
                statusIsError = true
            }
        }
    }

    @MainActor
    private func deleteSelectedPhotos() {
        let urls = selectedPhotoURLs
        guard !urls.isEmpty else { return }

        isDeleting = true
        statusMessage = ""

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                PhotoLibraryService.moveToTrash(urls)
            }.value

            isDeleting = false
            let failedText = result.failedPaths.isEmpty ? "" : "，\(result.failedPaths.count) 张失败"
            statusIsError = !result.failedPaths.isEmpty
            let prefix = "已移到废纸篓 \(result.deletedCount) 张照片\(failedText)。"

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
        .frame(width: DesignSystem.photoThumbnailSize, height: DesignSystem.photoThumbnailSize)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.panelRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: DesignSystem.borderWidth)
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
        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: DesignSystem.photoThumbnailSize, height: DesignSystem.photoThumbnailSize)
        )
    }
}
#endif
