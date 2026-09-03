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

    var body: some View {
        CorePageContainer(title: "照片整理", maxWidth: SYDownloadLayout.contentMaxWidth) {
            VStack(alignment: .leading, spacing: CoreSpacing.l) {
                workspace

                if shouldShowStatus {
                    Label(
                        statusMessage,
                        systemImage: statusIsError ? "exclamationmark.circle" : "checkmark.circle"
                    )
                    .font(CoreTypography.bodyFont)
                    .foregroundStyle(statusIsError ? CoreColor.danger : CoreColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
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
            Image(systemName: isDropTargeted ? "folder.fill.badge.plus" : "folder")
                .font(.system(size: CoreMetrics.controlHeightLarge, weight: .regular))
                .foregroundStyle(isDropTargeted ? CoreColor.accent : CoreColor.textSecondary)

            Text("拖入照片文件夹到这里")
                .font(CoreTypography.sectionTitleFont)

            Text("会读取文件夹中的图片并按文件名日期分组")
                .font(CoreTypography.bodyFont)
                .foregroundStyle(CoreColor.textSecondary)

            Button("选择文件夹…", systemImage: "folder", action: chooseFolder)
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
                    Label(folderURL.path, systemImage: "folder")
                        .font(CoreTypography.bodyFont)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(folderURL.path)
                }

                Spacer(minLength: CoreSpacing.m)

                Button("重新扫描", systemImage: "arrow.clockwise", action: rescan)
                    .buttonStyle(.borderless)
                    .font(CoreTypography.controlFont)
                    .frame(height: CoreMetrics.controlHeightCompact)
                    .disabled(isDeleting || isScanning)

                Button("更换文件夹…", systemImage: "folder", action: chooseFolder)
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
                        allDatesSelected ? "取消全选" : "全选日期",
                        systemImage: allDatesSelected ? "minus.square" : "checkmark.square",
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
            Image(systemName: "questionmark.circle")
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
                    width: RefinementLayout.photoCoverWidth,
                    height: RefinementLayout.photoCoverHeight,
                    cornerRadius: CoreRadius.panel
                )
            }

            if !supportingPhotos.isEmpty {
                LazyVGrid(columns: columns, spacing: RefinementLayout.photoPreviewSpacing) {
                    ForEach(Array(supportingPhotos.enumerated()), id: \.element.id) { index, photo in
                        if index == 3 && photos.count > 5 {
                            photoOverflowTile(count: photos.count - 4)
                        } else {
                            LocalPhotoThumbnail(
                                url: photo.url,
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

    private func photoOverflowTile(count: Int) -> some View {
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
        .accessibilityLabel("还有 \(count) 张照片")
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
                    Label("移到废纸篓", systemImage: "trash")
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
    var width: CGFloat = SYDownloadLayout.photoThumbnailSize
    var height: CGFloat = SYDownloadLayout.photoThumbnailSize
    var cornerRadius: CGFloat = CoreRadius.panel

    @State private var thumbnailImage: NSImage?

    var body: some View {
        Group {
            if let thumbnailImage {
                Image(nsImage: thumbnailImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.primary.opacity(0.04)
                    Image(systemName: "photo")
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
        .onTapGesture {
            PhotoQuickLookPresenter.shared.open(url)
        }
        .task(id: url) {
            await loadThumbnail()
        }
        .help("点按使用快速查看预览 \(url.lastPathComponent)")
        .accessibilityLabel(url.lastPathComponent)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            PhotoQuickLookPresenter.shared.open(url)
        }
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

    private var previewURL: URL?

    func open(_ url: URL) {
        previewURL = url
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.currentPreviewItemIndex = 0
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard index == 0, let previewURL else { return nil }
        return previewURL as NSURL
    }
}
#endif
