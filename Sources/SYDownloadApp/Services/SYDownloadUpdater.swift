#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import Combine
import CryptoKit
import Foundation
import SwiftUI

enum SYDownloadUpdateSource: String, CaseIterable, Identifiable {
    case github
    case ghProxy = "gh-proxy.com"
    case ghproxyNet = "ghproxy.net"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .github: return "GitHub"
        case .ghProxy: return "gh-proxy.com"
        case .ghproxyNet: return "ghproxy.net"
        }
    }

    var proxyPrefix: String? {
        switch self {
        case .github: return nil
        case .ghProxy: return "https://gh-proxy.com/"
        case .ghproxyNet: return "https://ghproxy.net/"
        }
    }
}

struct SYDownloadUpdateEndpoint {
    static func resolve(originalURL: URL, source: SYDownloadUpdateSource) -> URL? {
        guard let proxyPrefix = source.proxyPrefix else { return originalURL }
        guard let resolved = URL(string: "\(proxyPrefix)\(originalURL.absoluteString)"),
              resolved.scheme?.lowercased() == "https",
              resolved.host != nil else {
            return nil
        }
        return resolved
    }
}

struct SYDownloadReleaseAsset: Codable {
    let name: String
    let url: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case url
        case browserDownloadURL = "browser_download_url"
    }
}

struct SYDownloadRelease: Codable, Identifiable {
    let id: Int
    let tagName: String
    let name: String
    let body: String
    let assets: [SYDownloadReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case name
        case body
        case assets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        tagName = try container.decode(String.self, forKey: .tagName)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? tagName
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        assets = try container.decodeIfPresent([SYDownloadReleaseAsset].self, forKey: .assets) ?? []
    }
}

struct SYDownloadVersion: Comparable, Equatable {
    let components: [Int]

    init?(_ rawValue: String) {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .drop(while: { $0 == "v" || $0 == "V" })
        let core = normalized.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true).first ?? ""
        let parts = core.split(separator: ".", omittingEmptySubsequences: true)
        guard !parts.isEmpty, parts.allSatisfy({ Int($0) != nil }) else { return nil }
        components = parts.map { Int($0)! } + Array(repeating: 0, count: max(0, 3 - parts.count))
    }

    static func < (lhs: SYDownloadVersion, rhs: SYDownloadVersion) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}

struct SYDownloadPendingInstallation: Codable {
    let destinationPath: String
    let backupPath: String
    let bundleIdentifier: String
    let expectedVersion: String
}

struct SYDownloadUpdateInstaller {
    private static let statusFileName = "install-status"
    private static let recordFileName = "install-record.json"

    static func installScript(
        stagedApp: URL,
        destination: URL,
        updateRoot: URL,
        backupName: String,
        expectedBundleIdentifier: String,
        expectedVersion: String,
        parentProcessID: Int32? = nil
    ) -> String {
        let backup = destination.deletingLastPathComponent().appendingPathComponent(backupName)
        let candidate = destination.deletingLastPathComponent()
            .appendingPathComponent(".SYDownload-install-\(UUID().uuidString)", isDirectory: true)
        let status = updateRoot.appendingPathComponent(statusFileName)
        let stopParent = parentProcessID.map { """
        parent_pid=\($0)

        wait_for_parent_exit() {
            local seconds="$1"
            local waited=0
            while /bin/kill -0 "$parent_pid" >/dev/null 2>&1; do
                if (( waited >= seconds )); then
                    return 1
                fi
                /bin/sleep 1
                waited=$((waited + 1))
            done
            return 0
        }

        if ! wait_for_parent_exit 6; then
            /bin/kill -TERM "$parent_pid" >/dev/null 2>&1 || true
            if ! wait_for_parent_exit 3; then
                /bin/kill -KILL "$parent_pid" >/dev/null 2>&1 || true
                if ! wait_for_parent_exit 2; then
                    write_status "failed_parent_exit"
                    exit 1
                fi
            fi
        fi
        """ } ?? ""

        return """
        #!/bin/zsh
        set -u
        old=\(shellQuote(destination.path))
        new=\(shellQuote(stagedApp.path))
        backup=\(shellQuote(backup.path))
        candidate=\(shellQuote(candidate.path))
        status_path=\(shellQuote(status.path))
        expected_id=\(shellQuote(expectedBundleIdentifier))
        expected_version=\(shellQuote(expectedVersion))

        write_status() {
            /usr/bin/printf '%s\\n' "$1" > "$status_path" 2>/dev/null || true
        }

        remove_candidate() {
            if [[ -e "$candidate" ]]; then
                /bin/rm -rf "$candidate" >/dev/null 2>&1 || true
            fi
        }

        verify_bundle() {
            local bundle="$1"
            [[ -d "$bundle" ]] || return 1
            local actual_id actual_version
            actual_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$bundle/Contents/Info.plist" 2>/dev/null) || return 1
            actual_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$bundle/Contents/Info.plist" 2>/dev/null) || return 1
            [[ "$actual_id" == "$expected_id" && "$actual_version" == "$expected_version" ]]
        }

        restore_backup() {
            if [[ -e "$old" ]]; then
                /bin/rm -rf "$old" >/dev/null 2>&1 || return 1
            fi
            /bin/mv "$backup" "$old" >/dev/null 2>&1 || return 1
            verify_bundle "$old"
        }

        \(stopParent)

        if ! /usr/bin/ditto "$new" "$candidate" >/dev/null 2>&1; then
            remove_candidate
            write_status "failed_preflight"
            exit 1
        fi
        if ! verify_bundle "$candidate"; then
            remove_candidate
            write_status "failed_preflight"
            exit 1
        fi
        if ! /bin/mv "$old" "$backup" >/dev/null 2>&1; then
            remove_candidate
            write_status "failed_swap"
            exit 1
        fi
        if ! /bin/mv "$candidate" "$old" >/dev/null 2>&1; then
            if restore_backup; then
                write_status "failed_swap_restored"
            else
                write_status "failed_restore"
            fi
            remove_candidate
            exit 1
        fi
        if ! verify_bundle "$old"; then
            if restore_backup; then
                write_status "failed_post_install_restored"
            else
                write_status "failed_restore"
            fi
            exit 1
        fi

        write_status "installed"
        /usr/bin/open "$old" >/dev/null 2>&1 || write_status "installed_open_failed"
        exit 0
        """
    }

    static func pendingInstallationRecord(
        destination: URL,
        backupName: String,
        bundleIdentifier: String,
        expectedVersion: String
    ) -> SYDownloadPendingInstallation {
        SYDownloadPendingInstallation(
            destinationPath: destination.path,
            backupPath: destination.deletingLastPathComponent().appendingPathComponent(backupName).path,
            bundleIdentifier: bundleIdentifier,
            expectedVersion: expectedVersion
        )
    }

    static func finalizePendingInstallation(
        in updatesDirectory: URL,
        installedAppURL: URL,
        installedBundleIdentifier: String?,
        installedVersion: String,
        fileManager: FileManager = .default
    ) -> String? {
        guard let roots = try? fileManager.contentsOfDirectory(
            at: updatesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for root in roots {
            let statusURL = root.appendingPathComponent(statusFileName)
            guard let status = try? String(contentsOf: statusURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  status == "installed" || status == "installed_open_failed" else {
                continue
            }
            let recordURL = root.appendingPathComponent(recordFileName)
            guard let data = try? Data(contentsOf: recordURL),
                  let record = try? JSONDecoder().decode(SYDownloadPendingInstallation.self, from: data) else {
                return "更新已安装，但无法读取回滚记录；旧版本副本已保留。"
            }
            guard record.destinationPath == installedAppURL.path,
                  record.bundleIdentifier == installedBundleIdentifier,
                  record.expectedVersion == installedVersion else {
                return "更新已安装，但无法确认当前版本；旧版本副本已保留。"
            }

            do {
                if fileManager.fileExists(atPath: record.backupPath) {
                    try fileManager.removeItem(atPath: record.backupPath)
                }
                try fileManager.removeItem(at: root)
            } catch {
                return "更新成功，但回滚副本清理失败，已保留以便恢复。"
            }
        }
        return nil
    }

    static func pendingFailureMessage(
        in updatesDirectory: URL,
        fileManager: FileManager = .default
    ) -> String? {
        guard let roots = try? fileManager.contentsOfDirectory(
            at: updatesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for root in roots {
            let statusURL = root.appendingPathComponent(statusFileName)
            guard let status = try? String(contentsOf: statusURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  status.hasPrefix("failed_") else { continue }

            let message: String
            switch status {
            case "failed_parent_exit":
                message = "无法自动关闭当前 SYDownload，未执行覆盖安装。"
            case "failed_restore":
                message = "更新失败，且无法恢复旧版本；回滚副本已保留。"
            case "failed_swap_restored", "failed_post_install_restored":
                message = "更新失败，已恢复到原版本。"
            default:
                message = "更新在安装完成前失败，当前版本没有被替换。"
            }
            if status != "failed_restore" {
                try? fileManager.removeItem(at: root)
            }
            return message
        }
        return nil
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

private final class SYDownloadProcessOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Data()

    func set(_ data: Data) {
        lock.lock()
        value = data
        lock.unlock()
    }

    func get() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

struct SYDownloadUpdateProcessRunner {
    static func run(executable: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try runSynchronously(executable: executable, arguments: arguments))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func runSynchronously(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let output = SYDownloadProcessOutput()
        let readGroup = DispatchGroup()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()

        readGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            output.set(outputPipe.fileHandleForReading.readDataToEndOfFile())
            readGroup.leave()
        }

        process.waitUntilExit()
        readGroup.wait()

        let text = String(data: output.get(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            throw SYDownloadUpdateError.processFailed(text.isEmpty ? executable : text)
        }
        return text
    }
}

@MainActor
final class SYDownloadUpdater: ObservableObject {
    @Published var sheet = false
    @Published var releases: [SYDownloadRelease] = []
    @Published var updateAvailable = false
    @Published var progressBar: (String, Double) = ("", 0)
    @Published var updateSource: SYDownloadUpdateSource {
        didSet { defaults.set(updateSource.rawValue, forKey: Keys.updateSource) }
    }
    @Published private(set) var isChecking = false
    @Published private(set) var isUpdating = false
    @Published private(set) var updateError: String?

    let owner: String
    let repo: String

    private let defaults: UserDefaults
    private let automaticCheckInterval: TimeInterval = 86_400

    private enum Keys {
        static let lastCheckDate = "sydownload.updater.lastCheckDate"
        static let updateSource = "sydownload.updater.updateSource"
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var displayVersion: String {
        let normalized = currentVersion
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .drop(while: { $0 == "v" || $0 == "V" })
        return "v\(normalized)"
    }

    var latestRelease: SYDownloadRelease? { releases.first }

    var hasNewerRelease: Bool {
        guard let installed = SYDownloadVersion(currentVersion) else { return false }
        return releases
            .compactMap { SYDownloadVersion($0.tagName) }
            .contains(where: { $0 > installed })
    }

    init(owner: String, repo: String, defaults: UserDefaults = .standard) {
        self.owner = owner
        self.repo = repo
        self.defaults = defaults
        if let raw = defaults.string(forKey: Keys.updateSource),
           let source = SYDownloadUpdateSource(rawValue: raw) {
            self.updateSource = source
        } else {
            self.updateSource = .github
        }

        recordPendingInstallationState()

        Task { [weak self] in
            self?.checkAndUpdateIfNeeded()
        }
    }

    func checkForUpdates(sheet: Bool = false, force: Bool = false) {
        guard !isChecking, !isUpdating else { return }
        if sheet { self.sheet = true }
        isChecking = true
        updateError = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                releases = try await fetchReleases()
                updateAvailable = hasNewerRelease
                defaults.set(Date().timeIntervalSinceReferenceDate, forKey: Keys.lastCheckDate)
                if updateAvailable || force {
                    self.sheet = true
                }
            } catch {
                releases = []
                updateAvailable = false
                updateError = error.localizedDescription
                if sheet || force {
                    self.sheet = true
                }
            }
            isChecking = false
        }
    }

    func checkAndUpdateIfNeeded() {
        let stored = defaults.double(forKey: Keys.lastCheckDate)
        let lastCheck = stored == 0 ? Date.distantPast : Date(timeIntervalSinceReferenceDate: stored)
        guard Date().timeIntervalSince(lastCheck) >= automaticCheckInterval else { return }
        checkForUpdates()
    }

    func downloadUpdate() {
        guard !isUpdating, hasNewerRelease, let release = installableRelease else { return }
        isUpdating = true
        updateError = nil
        progressBar = ("正在准备更新…", 0.05)

        Task { [weak self] in
            guard let self else { return }
            do {
                try await stageAndLaunchUpdate(release: release)
            } catch {
                isUpdating = false
                updateAvailable = false
                updateError = error.localizedDescription
                progressBar = ("更新失败", 0)
            }
        }
    }

    private var installableRelease: SYDownloadRelease? {
        guard let current = SYDownloadVersion(currentVersion) else { return releases.first }
        return releases.first(where: { release in
            guard let version = SYDownloadVersion(release.tagName) else { return false }
            return version > current
        })
    }

    private func fetchReleases() async throws -> [SYDownloadRelease] {
        guard let githubURL = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases") else {
            throw SYDownloadUpdateError.invalidURL
        }
        let url = try updateURL(for: githubURL)
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("SYDownload/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SYDownloadUpdateError.invalidResponse }
        guard http.statusCode == 200 else { throw SYDownloadUpdateError.httpStatus(http.statusCode) }

        let decoded = try JSONDecoder().decode([SYDownloadRelease].self, from: data)
        return Array(decoded.sorted { lhs, rhs in
            guard let left = SYDownloadVersion(lhs.tagName), let right = SYDownloadVersion(rhs.tagName) else {
                return lhs.tagName > rhs.tagName
            }
            return left > right
        }.prefix(3))
    }

    private func stageAndLaunchUpdate(release: SYDownloadRelease) async throws {
        guard let asset = selectUpdateAsset(from: release.assets) else {
            throw SYDownloadUpdateError.noDownload
        }
        guard let originalDownloadURL = URL(string: asset.browserDownloadURL.isEmpty ? asset.url : asset.browserDownloadURL) else {
            throw SYDownloadUpdateError.invalidURL
        }
        let downloadURL = try updateURL(for: originalDownloadURL)
        let destination = Bundle.main.bundleURL
        let destinationParent = destination.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: destinationParent.path) else {
            throw SYDownloadUpdateError.installLocationNotWritable(destinationParent.path)
        }

        let fileManager = FileManager.default
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let updateRoot = support
            .appendingPathComponent("SYDownload", isDirectory: true)
            .appendingPathComponent("Updates", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: updateRoot, withIntermediateDirectories: true)
        var installerLaunched = false
        defer {
            if !installerLaunched {
                try? fileManager.removeItem(at: updateRoot)
            }
        }

        progressBar = ("正在下载更新…", 0.2)
        var request = URLRequest(url: downloadURL)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw SYDownloadUpdateError.downloadFailed
        }

        let archiveURL = updateRoot.appendingPathComponent(asset.name)
        try data.write(to: archiveURL, options: .atomic)

        progressBar = ("正在校验更新…", 0.4)
        try await verifyChecksum(archiveURL: archiveURL, asset: asset, release: release)

        let extractionURL = updateRoot.appendingPathComponent("extracted", isDirectory: true)
        try fileManager.createDirectory(at: extractionURL, withIntermediateDirectories: true)
        _ = try await SYDownloadUpdateProcessRunner.run(
            executable: "/usr/bin/ditto",
            arguments: ["-xk", archiveURL.path, extractionURL.path]
        )

        let appURLs = (fileManager.enumerator(at: extractionURL, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL } ?? [])
            .filter { $0.pathExtension == "app" }
        guard appURLs.count == 1 else { throw SYDownloadUpdateError.invalidArchive }
        let stagedApp = appURLs[0]

        guard let currentBundleIdentifier = Bundle.main.bundleIdentifier,
              let stagedBundle = Bundle(url: stagedApp),
              stagedBundle.bundleIdentifier == currentBundleIdentifier,
              let stagedShortVersion = stagedBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let stagedVersion = SYDownloadVersion(stagedShortVersion),
              let releaseVersion = SYDownloadVersion(release.tagName),
              stagedVersion == releaseVersion else {
            throw SYDownloadUpdateError.invalidArchive
        }

        progressBar = ("正在准备安装…", 0.7)
        try launchInstaller(
            stagedApp: stagedApp,
            updateRoot: updateRoot,
            expectedBundleIdentifier: currentBundleIdentifier,
            expectedVersion: stagedShortVersion
        )
        installerLaunched = true
        progressBar = ("正在关闭 SYDownload…", 1)
        NSApp.terminate(nil)
    }

    private func verifyChecksum(
        archiveURL: URL,
        asset: SYDownloadReleaseAsset,
        release: SYDownloadRelease
    ) async throws {
        guard let checksumAsset = release.assets.first(where: {
            let name = $0.name.lowercased()
            return name == "sha256sums" || name == "sha256sums.txt" || name.contains("checksums")
        }) else {
            throw SYDownloadUpdateError.missingChecksum
        }
        guard let originalURL = URL(string: checksumAsset.browserDownloadURL.isEmpty ? checksumAsset.url : checksumAsset.browserDownloadURL) else {
            throw SYDownloadUpdateError.invalidURL
        }
        let url = try updateURL(for: originalURL)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let text = String(data: data, encoding: .utf8) else {
            throw SYDownloadUpdateError.checksumUnavailable
        }

        let expected = text.split(whereSeparator: \.isNewline).compactMap { line -> String? in
            let fields = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard fields.count == 2 else { return nil }
            let filename = fields[1].trimmingCharacters(in: CharacterSet(charactersIn: " *"))
            return filename == asset.name ? String(fields[0]).lowercased() : nil
        }.first
        guard let expected else { throw SYDownloadUpdateError.checksumMissingForAsset }

        let digest = SHA256.hash(data: try Data(contentsOf: archiveURL))
        let actual = digest.map { String(format: "%02x", $0) }.joined()
        guard actual == expected else { throw SYDownloadUpdateError.checksumMismatch }
    }

    private func updateURL(for originalURL: URL) throws -> URL {
        guard let resolved = SYDownloadUpdateEndpoint.resolve(originalURL: originalURL, source: updateSource) else {
            throw SYDownloadUpdateError.invalidURL
        }
        return resolved
    }

    private func selectUpdateAsset(from assets: [SYDownloadReleaseAsset]) -> SYDownloadReleaseAsset? {
        let zipAssets = assets.filter { $0.name.lowercased().hasSuffix(".zip") }
#if arch(arm64)
        return zipAssets.first(where: { $0.name == "SYDownload-macOS-AppleSilicon.zip" }) ?? zipAssets.first
#else
        return zipAssets.first(where: { $0.name.localizedCaseInsensitiveContains("intel") }) ?? zipAssets.first
#endif
    }

    private func launchInstaller(
        stagedApp: URL,
        updateRoot: URL,
        expectedBundleIdentifier: String,
        expectedVersion: String
    ) throws {
        let destination = Bundle.main.bundleURL
        let backupName = ".SYDownload-backup-\(UUID().uuidString)"
        let record = SYDownloadUpdateInstaller.pendingInstallationRecord(
            destination: destination,
            backupName: backupName,
            bundleIdentifier: expectedBundleIdentifier,
            expectedVersion: expectedVersion
        )
        try JSONEncoder().encode(record).write(
            to: updateRoot.appendingPathComponent("install-record.json"),
            options: .atomic
        )

        let scriptURL = updateRoot.appendingPathComponent("install-update.zsh")
        let script = SYDownloadUpdateInstaller.installScript(
            stagedApp: stagedApp,
            destination: destination,
            updateRoot: updateRoot,
            backupName: backupName,
            expectedBundleIdentifier: expectedBundleIdentifier,
            expectedVersion: expectedVersion,
            parentProcessID: ProcessInfo.processInfo.processIdentifier
        )
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    private func recordPendingInstallationState() {
        let fileManager = FileManager.default
        guard let support = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }
        let updatesDirectory = support.appendingPathComponent("SYDownload/Updates", isDirectory: true)
        if let message = SYDownloadUpdateInstaller.finalizePendingInstallation(
            in: updatesDirectory,
            installedAppURL: Bundle.main.bundleURL,
            installedBundleIdentifier: Bundle.main.bundleIdentifier,
            installedVersion: currentVersion,
            fileManager: fileManager
        ) {
            updateError = message
        } else if let message = SYDownloadUpdateInstaller.pendingFailureMessage(
            in: updatesDirectory,
            fileManager: fileManager
        ) {
            updateError = message
        }
    }
}

private enum SYDownloadUpdateError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case noDownload
    case downloadFailed
    case missingChecksum
    case checksumUnavailable
    case checksumMissingForAsset
    case checksumMismatch
    case invalidArchive
    case installLocationNotWritable(String)
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "更新地址无效。"
        case .invalidResponse: return "更新源返回了无效响应。"
        case let .httpStatus(status): return "更新源返回 HTTP \(status)。"
        case .noDownload: return "当前版本没有可用的 macOS 更新包。"
        case .downloadFailed: return "更新包下载失败。"
        case .missingChecksum: return "该 Release 缺少 SHA-256 校验文件。"
        case .checksumUnavailable: return "无法下载 Release 校验文件。"
        case .checksumMissingForAsset: return "校验文件中没有当前更新包的记录。"
        case .checksumMismatch: return "更新包 SHA-256 校验失败。"
        case .invalidArchive: return "更新包中没有唯一且版本匹配的 SYDownload.app。"
        case let .installLocationNotWritable(path): return "无法替换位于 \(path) 的应用，请先把 SYDownload 移到可写目录。"
        case let .processFailed(command): return "更新处理命令失败：\(command)"
        }
    }
}

struct SYDownloadUpdateSheet: View {
    @ObservedObject var updater: SYDownloadUpdater
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SYDownload 更新")
                        .font(.title2.weight(.semibold))
                    Text("当前版本：\(updater.displayVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if updater.isChecking {
                    ProgressView().controlSize(.small)
                }
            }

            HStack {
                Text("更新来源")
                    .font(.callout)
                Spacer()
                Picker("更新来源", selection: $updater.updateSource) {
                    ForEach(SYDownloadUpdateSource.allCases) { source in
                        Text(source.displayName).tag(source)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
                Button("重新检查") {
                    updater.checkForUpdates(sheet: true, force: true)
                }
                .disabled(updater.isChecking || updater.isUpdating)
            }

            GroupBox {
                updateContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            if updater.isUpdating {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: updater.progressBar.1)
                    Text(updater.progressBar.0)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("关闭") { dismiss() }
                Spacer()
                if let url = URL(string: "https://github.com/\(updater.owner)/\(updater.repo)/releases") {
                    Button("Release 页面") { NSWorkspace.shared.open(url) }
                }
                Button("更新并重启") {
                    updater.downloadUpdate()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!updater.hasNewerRelease || updater.isChecking || updater.isUpdating)
            }
        }
        .padding(24)
        .frame(width: 600, height: 460)
    }

    @ViewBuilder
    private var updateContent: some View {
        if let error = updater.updateError {
            VStack(alignment: .leading, spacing: 8) {
                Label("更新检查失败", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(12)
        } else if let release = updater.latestRelease {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(release.name.isEmpty ? release.tagName : release.name)
                            .font(.headline)
                        Spacer()
                        Text(release.tagName)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    if updater.hasNewerRelease {
                        Label("发现新版本", systemImage: "arrow.down.circle.fill")
                            .foregroundStyle(.secondary)
                    } else {
                        Label("已是最新版本", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    if release.body.isEmpty {
                        Text("该版本没有发布说明。")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(release.body)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if updater.isChecking {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("正在检查更新…")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        } else {
            Text("暂无 Release 信息。")
                .foregroundStyle(.secondary)
                .padding(12)
        }
    }
}
#endif
