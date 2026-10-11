#if canImport(ImageIO)
import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

/// Stateless native pipeline. All writes are staged and verified before publication.
enum ExifProcessingService {
    static func timestamp(from fileName: String, secondsSource: ExifSecondsSource) throws -> String {
        let stem = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let regex = try NSRegularExpression(pattern: #"(?<!\d)(\d{4})-(\d{2})-(\d{2})_(\d{2})\.(\d{2})\.(\d{2})_(\d+)(?!\d)"#)
        guard let match = regex.firstMatch(in: stem, range: NSRange(stem.startIndex..., in: stem)) else {
            throw ExifProcessingError.invalid("文件名不含 YYYY-MM-DD_HH.mm.ss_编号")
        }
        let numbers = (1...7).compactMap { index -> Int? in
            guard let range = Range(match.range(at: index), in: stem) else { return nil }
            return Int(stem[range], radix: 10)
        }
        guard numbers.count == 7 else { throw ExifProcessingError.invalid("文件名中的数字超出范围") }
        let second = secondsSource == .suffix ? numbers[6] : numbers[5]
        guard (0...59).contains(second) else { throw ExifProcessingError.invalid("秒数必须在 0–59 之间") }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: numbers[0], month: numbers[1], day: numbers[2], hour: numbers[3], minute: numbers[4], second: second)
        guard numbers[0] > 0, let date = calendar.date(from: components),
              calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date) == components else {
            throw ExifProcessingError.invalid("文件名中的日期或时间无效")
        }
        return String(format: "%04d:%02d:%02d %02d:%02d:%02d", numbers[0], numbers[1], numbers[2], numbers[3], numbers[4], second)
    }

    static func scan(folder: URL, options: ExifProcessingOptions) throws -> [ExifFilePlan] {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
        return try files.filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { url in
                try Task.checkCancellation()
                let values = try url.resourceValues(forKeys: keys)
                let convert = options.convertPNG && url.pathExtension.lowercased() == "png"
                let targetName = convert ? url.deletingPathExtension().lastPathComponent + ".jpg" : url.lastPathComponent
                var issue: String?
                var stamp: String?
                var originalDate = "未设置"
                var originalCreateDate = "未设置"
                var originalModifyDate = "未设置"
                var originalCamera = "未设置"
                if values.isRegularFile != true || values.isSymbolicLink == true {
                    issue = "仅处理普通图片文件，不跟随符号链接"
                } else if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                          CGImageSourceGetCount(source) == 1,
                          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                    let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
                    let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
                    originalDate = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String ?? "未设置"
                    originalCreateDate = exif[kCGImagePropertyExifDateTimeDigitized as String] as? String ?? "未设置"
                    originalModifyDate = tiff[kCGImagePropertyTIFFDateTime as String] as? String ?? "未设置"
                    originalCamera = [tiff[kCGImagePropertyTIFFMake as String] as? String, tiff[kCGImagePropertyTIFFModel as String] as? String].compactMap { $0 }.joined(separator: " / ")
                    if originalCamera.isEmpty { originalCamera = "未设置" }
                    if options.writeDates {
                        do { stamp = try timestamp(from: url.lastPathComponent, secondsSource: options.secondsSource) }
                        catch { issue = error.localizedDescription }
                    }
                    if !options.writeDates && !options.writeCamera && !convert { issue = "没有需要修改的项目" }
                    if options.writeCamera && (options.make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || options.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        issue = "请填写相机品牌和型号"
                    }
                } else {
                    issue = "图片无法读取或包含多帧，暂不处理"
                }
                return ExifFilePlan(source: url, targetName: targetName, timestamp: stamp, originalDate: originalDate, originalCreateDate: originalCreateDate, originalModifyDate: originalModifyDate, originalCamera: originalCamera, fileSize: values.fileSize ?? 0, modifiedAt: values.contentModificationDate, issue: issue)
            }
    }

    static func process(_ plan: ExifFilePlan, folder: URL, options: ExifProcessingOptions, backupFolder: URL) throws -> URL {
        try Task.checkCancellation()
        if let issue = plan.issue { throw ExifProcessingError.invalid(issue) }
        let fm = FileManager.default
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        try checkUnchanged(plan)
        let output = options.saveMode == .copies ? folder.appendingPathComponent("EXIF 输出", isDirectory: true) : folder
        try ensureDirectory(output)
        let target = output.appendingPathComponent(plan.targetName)
        let sameFile = target.resolvingSymlinksInPath() == plan.source.resolvingSymlinksInPath()
        guard sameFile || !fm.fileExists(atPath: target.path) else { throw ExifProcessingError.skipped("目标文件已存在，未覆盖") }
        let staging = output.appendingPathComponent(".exif-\(UUID().uuidString).\(plan.convertsPNG ? "jpg" : plan.source.pathExtension)")
        defer { try? fm.removeItem(at: staging) }
        guard let source = CGImageSourceCreateWithURL(plan.source as CFURL, nil), CGImageSourceGetCount(source) == 1,
              let type = CGImageSourceGetType(source),
              let original = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            throw ExifProcessingError.invalid("无法读取源图片")
        }
        if plan.convertsPNG || plan.source.pathExtension.lowercased() == "png" {
            // PNG's metadata-copy API can leave an existing eXIf chunk stale.
            // Rebuild PNG losslessly; JPEG metadata editing never re-encodes pixels.
            let outputType = plan.convertsPNG ? UTType.jpeg.identifier : UTType.png.identifier
            guard let destination = CGImageDestinationCreateWithURL(staging as CFURL, outputType as CFString, 1, nil) else { throw ExifProcessingError.invalid("无法创建图片输出") }
            var properties = editedProperties(original, timestamp: plan.timestamp, options: options)
            if plan.convertsPNG {
                properties[kCGImageDestinationLossyCompressionQuality as String] = options.jpegQuality
                properties[kCGImageDestinationBackgroundColor as String] = CGColor(gray: 1, alpha: 1)
            }
            CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw ExifProcessingError.invalid("图片写出失败") }
        } else {
            let metadata = CGImageMetadataCreateMutable()
            func set(_ dictionary: CFString, _ property: CFString, _ value: String) throws {
                guard CGImageMetadataSetValueMatchingImageProperty(metadata, dictionary, property, value as CFString) else {
                    throw ExifProcessingError.invalid("元数据写入失败：\(property)")
                }
            }
            if let stamp = plan.timestamp, options.writeDates {
                try set(kCGImagePropertyExifDictionary, kCGImagePropertyExifDateTimeOriginal, stamp)
                try set(kCGImagePropertyExifDictionary, kCGImagePropertyExifDateTimeDigitized, stamp)
                try set(kCGImagePropertyTIFFDictionary, kCGImagePropertyTIFFDateTime, stamp)
            }
            if options.writeCamera {
                try set(kCGImagePropertyTIFFDictionary, kCGImagePropertyTIFFMake, options.make)
                try set(kCGImagePropertyTIFFDictionary, kCGImagePropertyTIFFModel, options.model)
            }
            guard let destination = CGImageDestinationCreateWithURL(staging as CFURL, type, 1, nil) else { throw ExifProcessingError.invalid("无法创建图片输出") }
            let settings: [String: Any] = [kCGImageDestinationMetadata as String: metadata, kCGImageDestinationMergeMetadata as String: true]
            var error: Unmanaged<CFError>?
            guard CGImageDestinationCopyImageSource(destination, source, settings as CFDictionary, &error) else {
                throw ExifProcessingError.invalid(error?.takeRetainedValue().localizedDescription ?? "当前图片不支持无重压缩修改")
            }
            // CopyImageSource finalizes the destination itself. Never finalize twice.
        }
        try verify(staging, original: original, plan: plan, options: options)
        try Task.checkCancellation()
        try checkUnchanged(plan)
        if options.saveMode == .replaceWithBackup {
            try ensureDirectory(backupFolder)
            let backup = backupFolder.appendingPathComponent(plan.source.lastPathComponent)
            guard !fm.fileExists(atPath: backup.path) else { throw ExifProcessingError.invalid("备份文件已存在，未覆盖") }
            try fm.copyItem(at: plan.source, to: backup)
            try Task.checkCancellation()
            if sameFile {
                _ = try fm.replaceItemAt(plan.source, withItemAt: staging)
            } else {
                try fm.moveItem(at: staging, to: target)
                do { try fm.removeItem(at: plan.source) }
                catch {
                    try? fm.removeItem(at: target)
                    throw error
                }
            }
        } else {
            try fm.moveItem(at: staging, to: target)
        }
        return target
    }

    private static func editedProperties(_ source: [String: Any], timestamp: String?, options: ExifProcessingOptions) -> [String: Any] {
        var properties = source
        var exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        var tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        if let timestamp, options.writeDates {
            exif[kCGImagePropertyExifDateTimeOriginal as String] = timestamp
            exif[kCGImagePropertyExifDateTimeDigitized as String] = timestamp
            tiff[kCGImagePropertyTIFFDateTime as String] = timestamp
        }
        if options.writeCamera {
            tiff[kCGImagePropertyTIFFMake as String] = options.make
            tiff[kCGImagePropertyTIFFModel as String] = options.model
        }
        properties[kCGImagePropertyExifDictionary as String] = exif
        properties[kCGImagePropertyTIFFDictionary as String] = tiff
        return properties
    }

    private static func verify(_ url: URL, original: [String: Any], plan: ExifFilePlan, options: ExifProcessingOptions) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let outputImage = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { throw ExifProcessingError.invalid("输出图片无法解码") }
        if plan.source.pathExtension.lowercased() == "png", !plan.convertsPNG {
            guard let input = CGImageSourceCreateWithURL(plan.source as CFURL, nil),
                  let inputImage = CGImageSourceCreateImageAtIndex(input, 0, nil),
                  let inputData = inputImage.dataProvider?.data,
                  let outputData = outputImage.dataProvider?.data,
                  inputImage.bitsPerComponent == outputImage.bitsPerComponent,
                  inputImage.bytesPerRow == outputImage.bytesPerRow,
                  inputImage.bitmapInfo == outputImage.bitmapInfo,
                  inputData as Data == outputData as Data else {
                throw ExifProcessingError.invalid("PNG 无损写出校验失败，原图未修改")
            }
        }
        let expected = editedProperties(original, timestamp: plan.timestamp, options: options)
        for (dictionary, keys) in [(kCGImagePropertyExifDictionary, [kCGImagePropertyExifDateTimeOriginal, kCGImagePropertyExifDateTimeDigitized]), (kCGImagePropertyTIFFDictionary, [kCGImagePropertyTIFFDateTime, kCGImagePropertyTIFFMake, kCGImagePropertyTIFFModel])] {
            let before = expected[dictionary as String] as? [String: Any] ?? [:]
            let after = properties[dictionary as String] as? [String: Any] ?? [:]
            for key in keys {
                if let value = before[key as String] as? String, after[key as String] as? String != value { throw ExifProcessingError.invalid("输出标签校验失败：\(key)（实际：\(after[key as String] ?? "缺失")）") }
            }
        }
        for key in [kCGImagePropertyPixelWidth, kCGImagePropertyPixelHeight, kCGImagePropertyOrientation] {
            if let value = original[key as String] as? NSNumber, properties[key as String] as? NSNumber != value { throw ExifProcessingError.invalid("输出尺寸或方向与原图不一致") }
        }
    }

    private static func checkUnchanged(_ plan: ExifFilePlan) throws {
        var freshURL = plan.source
        freshURL.removeAllCachedResourceValues()
        let values = try freshURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              values.fileSize == plan.fileSize, values.contentModificationDate == plan.modifiedAt else {
            throw ExifProcessingError.invalid("源文件已变化，请重新预览")
        }
    }

    private static func ensureDirectory(_ url: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else { throw ExifProcessingError.invalid("输出位置不是普通文件夹") }
        } else { try fm.createDirectory(at: url, withIntermediateDirectories: true) }
    }
}
#endif
