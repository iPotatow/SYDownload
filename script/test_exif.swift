// Compile together with ExifProcessingTypes.swift and ExifProcessingService.swift.
import Foundation
import Darwin
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

@main
struct ExifSmokeTests {
    static func main() throws {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: "/private/tmp/SYDownload-EXIF-tests-\(UUID().uuidString)", isDirectory: true).resolvingSymlinksInPath()
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        print("Fixtures: \(root.path)")
        func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
            guard try condition() else { throw ExifProcessingError.invalid("TEST FAILED: " + message) }
        }
        func rejects(_ name: String, _ source: ExifSecondsSource) throws {
            do { _ = try ExifProcessingService.timestamp(from: name, secondsSource: source) }
            catch { return }
            throw ExifProcessingError.invalid("Invalid timestamp accepted: \(name)")
        }
        try check(ExifProcessingService.timestamp(from: "2024-02-29_12.34.56_08.jpg", secondsSource: .suffix) == "2024:02:29 12:34:08", "decimal suffix")
        try check(ExifProcessingService.timestamp(from: "2024-02-29_12.34.56_64.jpg", secondsSource: .filename) == "2024:02:29 12:34:56", "filename seconds")
        try rejects("2023-02-29_12.34.56_08.jpg", .filename)
        try rejects("2024-02-29_12.34.56_64.jpg", .suffix)
        try rejects("2024-02-29_24.34.56_08.jpg", .filename)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: nil, width: 32, height: 24, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.7, alpha: 0.5))
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
        let image = context.makeImage()!
        let oldStamp = "2020:01:02 03:04:05"
        let metadata: [String: Any] = [
            kCGImagePropertyOrientation as String: 6,
            kCGImagePropertyExifDictionary as String: [kCGImagePropertyExifDateTimeOriginal as String: oldStamp, kCGImagePropertyExifUserComment as String: "Keep this comment"],
            kCGImagePropertyTIFFDictionary as String: [kCGImagePropertyTIFFMake as String: "Original", kCGImagePropertyTIFFModel as String: "Camera"]
        ]
        func fixture(_ name: String, _ type: UTType) throws -> URL {
            let url = root.appendingPathComponent(name)
            let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(destination, image, metadata as CFDictionary)
            try check(CGImageDestinationFinalize(destination), "fixture creation")
            return url
        }
        let jpg = try fixture("2024-02-29_12.34.56_08.jpg", .jpeg)
        let png = try fixture("2024-03-01_09.08.07_09.png", .png)
        let invalid = try fixture("2023-02-29_12.34.56_08.jpg", .jpeg)
        let jpgBytes = try Data(contentsOf: jpg)
        let pngBytes = try Data(contentsOf: png)
        var options = ExifProcessingOptions()
        options.writeCamera = true
        options.secondsSource = .suffix
        let plans = try ExifProcessingService.scan(folder: root, options: options)
        print(plans.map { ($0.source.path, $0.issue ?? "OK") })
        fflush(stdout)
        try check(plans.count == 3 && plans.first(where: { $0.source.path == invalid.path })?.issue != nil, "scan rejects invalid date")
        let backup = root.appendingPathComponent("backup")
        let jpegPlan = plans.first { $0.source.path == jpg.path }!
        let jpegOutput = try ExifProcessingService.process(jpegPlan, folder: root, options: options, backupFolder: backup)
        func props(_ url: URL) -> [String: Any] {
            CGImageSourceCopyPropertiesAtIndex(CGImageSourceCreateWithURL(url as CFURL, nil)!, 0, nil) as! [String: Any]
        }
        let result = props(jpegOutput)
        let exif = result[kCGImagePropertyExifDictionary as String] as! [String: Any]
        try check(exif[kCGImagePropertyExifUserComment as String] as? String == "Keep this comment", "unrelated EXIF preserved")
        // The JPEG entropy-coded image data must stay byte-for-byte identical.
        func compressedScan(_ bytes: Data) throws -> Data {
            let array = [UInt8](bytes)
            for i in 0..<(array.count - 1) where array[i] == 0xff && array[i + 1] == 0xda { return bytes.suffix(from: i) }
            throw ExifProcessingError.invalid("JPEG scan not found")
        }
        try check(compressedScan(jpgBytes) == compressedScan(Data(contentsOf: jpegOutput)), "JPEG not recompressed")
        try check(Data(contentsOf: jpg) == jpgBytes, "JPEG source unchanged")
        do {
            _ = try ExifProcessingService.process(jpegPlan, folder: root, options: options, backupFolder: backup)
            throw ExifProcessingError.invalid("Existing output overwritten")
        } catch ExifProcessingError.skipped { }
        // PNG metadata-only path must work without a format conversion.
        let pngPlan = plans.first { $0.source.path == png.path }!
        let pngOutput = try ExifProcessingService.process(pngPlan, folder: root, options: options, backupFolder: backup)
        func pixels(_ url: URL) -> Data {
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
            return image.dataProvider!.data! as Data
        }
        try check(pixels(png) == pixels(pngOutput), "PNG pixels unchanged")
        try check(Data(contentsOf: png) == pngBytes, "PNG source unchanged")
        try fm.removeItem(at: root.appendingPathComponent("EXIF 输出"))
        options.convertPNG = true
        options.saveMode = .replaceWithBackup
        let replacementPlans = try ExifProcessingService.scan(folder: root, options: options)
        let converted = try ExifProcessingService.process(replacementPlans.first { $0.source.path == png.path }!, folder: root, options: options, backupFolder: backup)
        try check(converted.pathExtension == "jpg" && !fm.fileExists(atPath: png.path), "PNG replaced with JPEG")
        try check(Data(contentsOf: backup.appendingPathComponent(png.lastPathComponent)) == pngBytes, "PNG backup exact")
        _ = try ExifProcessingService.process(replacementPlans.first { $0.source.path == jpg.path }!, folder: root, options: options, backupFolder: backup)
        try check(Data(contentsOf: backup.appendingPathComponent(jpg.lastPathComponent)) == jpgBytes, "JPEG backup exact")
        // An edit made after preview must prevent publication.
        let stale = try ExifProcessingService.scan(folder: root, options: options).first { $0.source.path == jpg.path }!
        try fm.setAttributes([.modificationDate: Date(timeIntervalSinceNow: 10)], ofItemAtPath: jpg.path)
        do {
            _ = try ExifProcessingService.process(stale, folder: root, options: options, backupFolder: backup)
            throw ExifProcessingError.invalid("Stale preview accepted")
        } catch ExifProcessingError.invalid(let reason) { try check(reason.contains("源文件已变化"), "source modification rejected") }
        print("PASS: dates, invalid inputs, native JPEG/PNG metadata, unchanged JPEG scan, original copies, collision, backup replacement, conversion, stale preview")
    }
}
