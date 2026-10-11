#if canImport(SwiftUI)
import Foundation
import Combine

/// App-owned workspace survives navigation while UI presentation stays in the view.
@MainActor
final class PhotoWorkspaceState: ObservableObject {
    @Published var folderURL: URL?
    @Published var scanResult = PhotoScanResult.empty
    @Published var selectedDates: Set<String> = []
    @Published var includesSubfolders = false
    @Published var isScanning = false
    @Published var isDeleting = false
    @Published var statusIsError = false
    @Published var statusMessage = ""
    @Published var failedDeleteURLs: [URL] = []
    var resultIncludesSubfolders = false
    var scanTask: Task<PhotoScanOutcome, Never>?
    var scanID = UUID()
}
#endif
