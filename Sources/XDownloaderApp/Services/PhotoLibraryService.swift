#if canImport(SwiftUI)
import Foundation
import UniformTypeIdentifiers

struct PhotoFileItem: Identifiable, Hashable, Sendable {
    let url: URL

    var id: URL { url }
}

struct PhotoDateGroup: Identifiable, Hashable, Sendable {
    let dateKey: String
    let sortDate: Date
    let photos: [PhotoFileItem]

    var id: String { dateKey }
}

struct PhotoScanResult: Sendable {
    let groups: [PhotoDateGroup]
    let ungrouped: [PhotoFileItem]

    static let empty = PhotoScanResult(groups: [], ungrouped: [])

    var recognizedCount: Int {
        groups.reduce(0) { $0 + $1.photos.count }
    }

    var totalCount: Int {
        recognizedCount + ungrouped.count
    }
}

enum PhotoScanOutcome: Sendable {
    case success(PhotoScanResult)
    case failure(String)
}

struct PhotoDeleteResult: Sendable {
    let deletedCount: Int
    let failedPaths: [String]
}

enum PhotoLibraryService {
    static func scan(folder: URL) throws -> PhotoScanResult {
        let resourceValues = try folder.resourceValues(forKeys: [.isDirectoryKey])
        guard resourceValues.isDirectory == true else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }

        let regexes = makeDateRegexes()
        let keys: Set<URLResourceKey> = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw CocoaError(.fileReadUnknown)
        }

        var grouped: [String: (date: Date, photos: [PhotoFileItem])] = [:]
        var ungrouped: [PhotoFileItem] = []

        for case let fileURL as URL in enumerator {
            guard isImageFile(fileURL) else { continue }
            guard (try? fileURL.resourceValues(forKeys: keys).isRegularFile) == true else { continue }

            let photo = PhotoFileItem(url: fileURL)
            if let parsed = dateInfo(fromFileName: fileURL.lastPathComponent, regexes: regexes) {
                if var existing = grouped[parsed.key] {
                    existing.photos.append(photo)
                    grouped[parsed.key] = existing
                } else {
                    grouped[parsed.key] = (parsed.date, [photo])
                }
            } else {
                ungrouped.append(photo)
            }
        }

        let groups = grouped.map { key, value in
            PhotoDateGroup(
                dateKey: key,
                sortDate: value.date,
                photos: value.photos.sorted(by: fileNameAscending)
            )
        }
        .sorted { lhs, rhs in
            lhs.sortDate > rhs.sortDate
        }

        return PhotoScanResult(
            groups: groups,
            ungrouped: ungrouped.sorted(by: fileNameAscending)
        )
    }

    static func moveToTrash(_ urls: [URL]) -> PhotoDeleteResult {
        let fileManager = FileManager.default
        var deletedCount = 0
        var failedPaths: [String] = []

        for url in urls {
            do {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
                deletedCount += 1
            } catch {
                failedPaths.append(url.path)
            }
        }

        return PhotoDeleteResult(deletedCount: deletedCount, failedPaths: failedPaths)
    }

    static func dateKey(fromFileName fileName: String) -> String? {
        dateInfo(fromFileName: fileName, regexes: makeDateRegexes())?.key
    }

    private static func makeDateRegexes() -> [NSRegularExpression] {
        [
            try! NSRegularExpression(
                pattern: #"(?<!\d)((?:19|20)\d{2})(?:[-_.]|年)(0?[1-9]|1[0-2])(?:[-_.]|月)(0?[1-9]|[12]\d|3[01])日?(?!\d)"#
            ),
            try! NSRegularExpression(
                pattern: #"(?<!\d)((?:19|20)\d{2})(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])(?!\d)"#
            ),
        ]
    }

    private static func isImageFile(_ url: URL) -> Bool {
        guard !url.pathExtension.isEmpty,
              let type = UTType(filenameExtension: url.pathExtension.lowercased())
        else { return false }
        return type.conforms(to: .image)
    }

    private static func dateInfo(
        fromFileName fileName: String,
        regexes: [NSRegularExpression]
    ) -> (key: String, date: Date)? {
        let stem = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let fullRange = NSRange(stem.startIndex..<stem.endIndex, in: stem)

        for regex in regexes {
            guard let match = regex.firstMatch(in: stem, range: fullRange),
                  let year = integerGroup(1, match: match, source: stem),
                  let month = integerGroup(2, match: match, source: stem),
                  let day = integerGroup(3, match: match, source: stem),
                  let date = validatedDate(year: year, month: month, day: day)
            else { continue }

            return (String(format: "%04d-%02d-%02d", year, month, day), date)
        }

        return nil
    }

    private static func integerGroup(
        _ index: Int,
        match: NSTextCheckingResult,
        source: String
    ) -> Int? {
        guard let range = Range(match.range(at: index), in: source) else { return nil }
        return Int(source[range])
    }

    private static func validatedDate(year: Int, month: Int, day: Int) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day

        guard let date = calendar.date(from: components) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        return date
    }

    private static func fileNameAscending(_ lhs: PhotoFileItem, _ rhs: PhotoFileItem) -> Bool {
        lhs.url.lastPathComponent.localizedStandardCompare(rhs.url.lastPathComponent) == .orderedAscending
    }
}
#endif
