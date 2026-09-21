#if canImport(SwiftUI)
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import QuickLookThumbnailing
import QuickLookUI

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
    @State private var scanTask: Task<PhotoScanOutcome, Never>?
    @State private var scanID = UUID()
    @State private var failedDeleteURLs: [URL] = []

    var body: some View {
        CorePageContainer(title: "照片整理", maxWidth: SYDownloadLayout.contentMaxWidth) {
            VStack(alignment: .leading, spacing: CoreSpacing.l) {
                workspace

                if shouldShowStatus {
                    VStack(alignment: .leading, spacing: CoreSpacing.s) {
                        Label(
                            statusMessage, remixSystemImage: statusIsError ? "exclamationmark.circle" : "checkmark.circle"
                        )
                        .font(CoreTypography.bodyFont)
                        .foregroundStyle(statusIsError ? CoreColor.danger : CoreColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)

                        if !failedDeleteURLs.isEmpty {
                            deleteFailureActions
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        .tint(CoreColor.accent)
    }

    private var shouldShowStatus: Bool {
        !statusMessage.isEmpty && !isScanning
    }

    @ViewBuilder
    private var workspace: some View {
        if folderURL == nil && !isScanning {
            initialDropZone
                .frame(maxWidth: .infinity, alignment: .topLeading)
        } else if isScanning {
            scanningState
                .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            photoGroups
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var initialDropZone: some View {
        VStack(spacing: CoreSpacing.m) {
            RemixIcon(systemName: isDropTargeted ? "folder.fill.badge.plus" : "folder", size: CoreMetrics.controlHeightLarge)
                .foregroundStyle(isDropTargeted ? CoreColor.accent : CoreColor.textSecondary)

            Text("拖入照片文件夹到这里")
                .font(CoreTypography.sectionTitleFont)

            Text("会读取文件夹中的图片并按文件名日期分组")
                .font(CoreTypography.bodyFont)
                .foregroundStyle(CoreColor.textSecondary)

            Button("选择文件夹…", remixSystemImage: "folder", action: chooseFolder)
                .buttonStyle(.borderedProminent)
                .font(CoreTypography.controlFont)
                .frame(height: CoreMetrics.controlHeightDefault)

            Text("支持 JPG、PNG、HEIC 等常见图片格式")
                .font(CoreTypography.captionFont)
                .foregroundStyle(CoreColor.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .background(
            isDropTargeted ? CoreColor.selectionBackground : CoreColor.panelBackground.opacity(0.38),
            in: RoundedRectangle(cornerRadius: CoreRadius.panel, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CoreRadius.panel, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? CoreColor.accent.opacity(0.70) : CoreColor.border.opacity(0.82),
                    style: StrokeStyle(lineWidth: CoreMetrics.borderWidth, dash: [8, 4])
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
        VStack(spacing: CoreSpacing.m) {
            ProgressView()
                .controlSize(.large)
                .tint(CoreColor.accent)
            Text("正在读取图片并解析文件名日期…")
                .font(CoreTypography.sectionTitleFont)
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(CoreTypography.bodyFont)
                    .foregroundStyle(CoreColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: CoreSpacing.s) {
                Button("取消扫描", role: .cancel) {
                    cancelScan()
                }
                .font(CoreTypography.controlFont)

                Button("更换文件夹…", remixSystemImage: "folder") {
                    cancelScan()
                    chooseFolder()
                }
                .font(CoreTypography.controlFont)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .background(
            CoreColor.panelBackground.opacity(0.38),
            in: RoundedRectangle(cornerRadius: CoreRadius.panel, style: .continuous)
        )
    }

    private var photoGroups: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.m) {
            summaryBar
            Divider()
                .overlay(CoreColor.divider)

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
                    LazyVStack(spacing: CoreSpacing.s) {
                        ForEach(scanResult.groups) { group in
                            dateGroupRow(group)
                        }

                        if !scanResult.ungrouped.isEmpty {
                            ungroupedRow
                        }
                    }
                    .padding(.bottom, selectedDates.isEmpty ? CoreSpacing.s : RefinementLayout.photoDeleteBarClearance)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !selectedDates.isEmpty {
                        deleteBar
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var summaryBar: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.s) {
            HStack(spacing: CoreSpacing.s) {
                if let folderURL {
                    Label(folderURL.path, remixSystemImage: "folder")
                        .font(CoreTypography.bodyFont)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(folderURL.path)
                }

                Spacer(minLength: CoreSpacing.m)

                Button("重新扫描", remixSystemImage: "arrow.clockwise", action: rescan)
                    .buttonStyle(.borderless)
                    .font(CoreTypography.controlFont)
                    .frame(height: CoreMetrics.controlHeightCompact)
                    .disabled(isDeleting || isScanning)

                Button("更换文件夹…", remixSystemImage: "folder", action: chooseFolder)
                    .buttonStyle(.bordered)
                    .font(CoreTypography.controlFont)
                    .frame(height: CoreMetrics.controlHeightCompact)
                    .disabled(isDeleting || isScanning)
            }

            HStack(spacing: CoreSpacing.m) {
                Text("\(scanResult.totalCount) 张照片")
                    .font(CoreTypography.bodyFont)
                    .foregroundStyle(CoreColor.textSecondary)
                Text("\(scanResult.groups.count) 个日期")
                    .font(CoreTypography.bodyFont)
                    .foregroundStyle(CoreColor.textSecondary)

                if !scanResult.ungrouped.isEmpty {
                    Text("\(scanResult.ungrouped.count) 张未识别日期")
                        .font(CoreTypography.bodyFont)
                        .foregroundStyle(CoreColor.textSecondary)
                }

                Spacer()

                if !scanResult.groups.isEmpty {
                    Button(
                        allDatesSelected ? "取消全选" : "全选日期", remixSystemImage: allDatesSelected ? "minus.square" : "checkmark.square",
                        action: toggleAllDates
                    )
                    .buttonStyle(.borderless)
                    .font(CoreTypography.controlFont)
                    .frame(height: CoreMetrics.controlHeightCompact)
                    .disabled(isDeleting)
                }
            }
        }
        .frame(minHeight: CoreMetrics.controlRowMinHeight)
    }

    private func dateGroupRow(_ group: PhotoDateGroup) -> some View {
        HStack(spacing: CoreSpacing.m) {
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

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text(group.dateKey)
                    .coreTypography(CoreTypography.control)
                    .foregroundStyle(CoreColor.textPrimary)
                Text("\(group.photos.count) 张照片")
                    .coreTypography(CoreTypography.caption)
                    .foregroundStyle(CoreColor.textSecondary)
            }
            .frame(width: RefinementLayout.photoDateColumnWidth, alignment: .leading)

            photoPreview(group.photos)

            Spacer(minLength: 0)
        }
        .padding(CoreSpacing.m)
        .background(
            selectedDates.contains(group.id) ? CoreColor.selectionBackground : CoreColor.controlBackground,
            in: RoundedRectangle(cornerRadius: CoreRadius.row, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CoreRadius.row, style: .continuous)
                .strokeBorder(
                    selectedDates.contains(group.id) ? CoreColor.accent.opacity(0.30) : CoreColor.divider,
                    lineWidth: CoreMetrics.borderWidth
                )
        }
    }

    private var ungroupedRow: some View {
        HStack(spacing: CoreSpacing.m) {
            RemixIcon(systemName: "questionmark.circle")
                .foregroundStyle(CoreColor.textSecondary)
                .frame(width: CoreSpacing.l)

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("未识别日期")
                    .coreTypography(CoreTypography.control)
                    .foregroundStyle(CoreColor.textPrimary)
                Text("\(scanResult.ungrouped.count) 张照片 · 不参与批量删除")
                    .coreTypography(CoreTypography.caption)
                    .foregroundStyle(CoreColor.textSecondary)
            }
            .frame(width: RefinementLayout.photoUngroupedColumnWidth, alignment: .leading)

            photoPreview(scanResult.ungrouped)
            Spacer(minLength: 0)
        }
        .padding(CoreSpacing.m)
        .background(
            CoreColor.controlBackground,
            in: RoundedRectangle(cornerRadius: CoreRadius.row, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CoreRadius.row, style: .continuous)
                .strokeBorder(CoreColor.divider, lineWidth: CoreMetrics.borderWidth)
        }
    }

    private func photoPreview(_ photos: [PhotoFileItem]) -> some View {
        let supportingPhotos = Array(photos.dropFirst().prefix(4))
        let columns = [
            GridItem(.fixed(RefinementLayout.photoSecondaryThumbnailSize), spacing: RefinementLayout.photoPreviewSpacing),
            GridItem(.fixed(RefinementLayout.photoSecondaryThumbnailSize), spacing: RefinementLayout.photoPreviewSpacing)
        ]

        return HStack(alignment: .top, spacing: RefinementLayout.photoPreviewSpacing) {
            if let cover = photos.first {
                LocalPhotoThumbnail(
                    url: cover.url,
                    previewURLs: photos.map(\.url),
                    previewIndex: 0,
                    width: RefinementLayout.photoCoverWidth,
                    height: RefinementLayout.photoCoverHeight,
                    cornerRadius: CoreRadius.panel
                )
            }

            if !supportingPhotos.isEmpty {
                LazyVGrid(columns: columns, spacing: RefinementLayout.photoPreviewSpacing) {
                    ForEach(Array(supportingPhotos.enumerated()), id: \.element.id) { index, photo in
                        if index == 3 && photos.count > 5 {
                            photoOverflowTile(count: photos.count - 4, photos: photos)
                        } else {
                            LocalPhotoThumbnail(
                                url: photo.url,
                                previewURLs: photos.map(\.url),
                                previewIndex: index + 1,
                                width: RefinementLayout.photoSecondaryThumbnailSize,
                                height: RefinementLayout.photoSecondaryThumbnailSize,
                                cornerRadius: CoreRadius.row
                            )
                        }
                    }
                }
                .frame(
                    width: RefinementLayout.photoSecondaryThumbnailSize * 2 + RefinementLayout.photoPreviewSpacing,
                    height: RefinementLayout.photoCoverHeight,
                    alignment: .top
                )
            }
        }
        .frame(height: RefinementLayout.photoCoverHeight, alignment: .leading)
    }

    private func photoOverflowTile(count: Int, photos: [PhotoFileItem]) -> some View {
        Button {
            PhotoQuickLookPresenter.shared.open(photos.map(\.url), startAt: min(4, max(0, photos.count - 1)))
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: CoreRadius.row, style: .continuous)
                    .fill(CoreColor.panelBackground)
                Text("+\(count)")
                    .coreTypography(CoreTypography.groupLabel)
                    .foregroundStyle(CoreColor.textSecondary)
                    .monospacedDigit()
            }
            .frame(
                width: RefinementLayout.photoSecondaryThumbnailSize,
                height: RefinementLayout.photoSecondaryThumbnailSize
            )
            .overlay {
                RoundedRectangle(cornerRadius: CoreRadius.row, style: .continuous)
                    .strokeBorder(CoreColor.divider, lineWidth: CoreMetrics.dividerWidth)
            }
        }
        .buttonStyle(.plain)
        .help("查看这一日期的全部 \(photos.count) 张照片")
        .accessibilityLabel("查看全部照片，还有 \(count) 张未显示")
    }

    private var deleteBar: some View {
        HStack(spacing: CoreSpacing.m) {
            Text("已选择 \(selectedDates.count) 个日期 · \(selectedPhotoURLs.count) 张照片")
                .font(CoreTypography.controlFont)
                .monospacedDigit()

            Spacer()

            Button("取消选择") {
                selectedDates.removeAll()
            }
            .font(CoreTypography.controlFont)
            .frame(height: CoreMetrics.controlHeightDefault)
            .disabled(isDeleting)

            Button(role: .destructive) {
                showsDeleteConfirmation = true
            } label: {
                if isDeleting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("移到废纸篓", remixSystemImage: "trash")
                }
            }
            .font(CoreTypography.controlFont)
            .frame(height: CoreMetrics.controlHeightDefault)
            .disabled(isDeleting || selectedPhotoURLs.isEmpty)
        }
        .padding(.horizontal, CoreMetrics.panelPadding)
        .padding(.vertical, CoreSpacing.s)
        .background(CoreColor.contentBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CoreColor.divider)
                .frame(height: CoreMetrics.dividerWidth)
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

    private var deleteFailureActions: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.s) {
            ForEach(Array(failedDeleteURLs.prefix(4)), id: \.self) { url in
                Text(url.lastPathComponent)
                    .coreTypography(CoreTypography.caption)
                    .foregroundStyle(CoreColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(url.path)
            }

            if failedDeleteURLs.count > 4 {
                Text("另有 \(failedDeleteURLs.count - 4) 个文件")
                    .coreTypography(CoreTypography.caption)
                    .foregroundStyle(CoreColor.textTertiary)
            }

            HStack(spacing: CoreSpacing.s) {
                Button("在 Finder 中显示", remixSystemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting(failedDeleteURLs)
                }
                .buttonStyle(.borderless)
                .font(CoreTypography.controlFont)

                Button("重试失败项", remixSystemImage: "arrow.clockwise") {
                    deletePhotos(failedDeleteURLs)
                }
                .buttonStyle(.borderless)
                .font(CoreTypography.controlFont)
                .disabled(isDeleting)
            }
        }
        .padding(.leading, CoreSpacing.l)
    }

    @MainActor
    private func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        scanID = UUID()
        isScanning = false
        statusIsError = false
        statusMessage = folderURL == nil ? "" : "已取消扫描。"
    }

    @MainActor
    private func openFolder(_ url: URL, statusPrefix: String? = nil) {
        scanTask?.cancel()
        let currentID = UUID()
        scanID = currentID
        folderURL = url
        selectedDates.removeAll()
        failedDeleteURLs.removeAll()
        isScanning = true
        statusIsError = false
        statusMessage = "正在扫描 \(url.lastPathComponent)…"

        let worker = Task.detached(priority: .userInitiated) { () -> PhotoScanOutcome in
            do {
                return PhotoScanOutcome.success(try PhotoLibraryService.scan(folder: url))
            } catch is CancellationError {
                return PhotoScanOutcome.failure("__cancelled__")
            } catch {
                return PhotoScanOutcome.failure(error.localizedDescription)
            }
        }
        scanTask = worker

        Task { @MainActor in
            let outcome = await worker.value
            guard scanID == currentID else { return }
            scanTask = nil
            isScanning = false

            switch outcome {
            case .success(let result):
                scanResult = result
                statusIsError = false
                statusMessage = statusPrefix ?? ""
            case .failure(let message):
                if message == "__cancelled__" {
                    statusMessage = "已取消扫描。"
                    statusIsError = false
                    return
                }
                scanResult = .empty
                statusMessage = "无法读取照片：\(message)"
                statusIsError = true
            }
        }
    }

    @MainActor
    private func deleteSelectedPhotos() {
        deletePhotos(selectedPhotoURLs)
    }

    @MainActor
    private func deletePhotos(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        isDeleting = true
        statusMessage = ""
        failedDeleteURLs.removeAll()

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                PhotoLibraryService.moveToTrash(urls)
            }.value

            isDeleting = false
            let failed = Set(result.failedPaths)
            failedDeleteURLs = urls.filter { failed.contains($0.path) }
            let failedText = result.failedPaths.isEmpty ? "" : "，\(result.failedPaths.count) 张失败"
            statusIsError = !result.failedPaths.isEmpty
            statusMessage = "已移到废纸篓 \(result.deletedCount) 张照片\(failedText)。"
            selectedDates.removeAll()

            if let folderURL {
                let preservedStatus = statusMessage
                let preservedFailures = failedDeleteURLs
                openFolder(folderURL, statusPrefix: preservedStatus)
                failedDeleteURLs = preservedFailures
            }
        }
    }
}

private struct LocalPhotoThumbnail: View {
    let url: URL
    var previewURLs: [URL]?
    var previewIndex: Int = 0
    var width: CGFloat = SYDownloadLayout.photoThumbnailSize
    var height: CGFloat = SYDownloadLayout.photoThumbnailSize
    var cornerRadius: CGFloat = CoreRadius.panel

    @State private var thumbnailImage: NSImage?

    var body: some View {
        Button {
            PhotoQuickLookPresenter.shared.open(previewURLs ?? [url], startAt: previewIndex)
        } label: {
            Group {
                if let thumbnailImage {
                    Image(nsImage: thumbnailImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color.primary.opacity(0.04)
                        RemixIcon(systemName: "photo")
                            .foregroundStyle(CoreColor.textSecondary)
                    }
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: CoreMetrics.borderWidth)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task(id: url) {
            await loadThumbnail()
        }
        .help("点按使用快速查看预览 \(url.lastPathComponent)")
        .accessibilityLabel("预览 \(url.lastPathComponent)")
    }

    @MainActor
    private func loadThumbnail() async {
        thumbnailImage = nil

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: width, height: height),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            guard !Task.isCancelled else {
                QLThumbnailGenerator.shared.cancel(request)
                return
            }
            thumbnailImage = representation.nsImage
        } catch {
            if Task.isCancelled {
                QLThumbnailGenerator.shared.cancel(request)
            }
            thumbnailImage = nil
        }
    }
}

@MainActor
private final class PhotoQuickLookPresenter: NSObject, @MainActor QLPreviewPanelDataSource {
    static let shared = PhotoQuickLookPresenter()

    private var previewURLs: [URL] = []

    func open(_ url: URL) {
        open([url], startAt: 0)
    }

    func open(_ urls: [URL], startAt index: Int = 0) {
        previewURLs = urls
        guard let panel = QLPreviewPanel.shared(), !urls.isEmpty else { return }
        panel.dataSource = self
        panel.reloadData()
        panel.currentPreviewItemIndex = min(max(index, 0), urls.count - 1)
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURLs.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard previewURLs.indices.contains(index) else { return nil }
        return previewURLs[index] as NSURL
    }
}
#endif
