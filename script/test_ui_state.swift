import Foundation
import ImageIO
import CoreGraphics
import SYDownloadCore

private actor SettingsBridge {
    var failing = false
    func fail() { failing = true }
    func send(_ request: BridgeRequest) -> BridgeResponse {
        BridgeResponse(ok: !failing, message: failing ? "fixture failure" : "ok", details: ["folder_name": "Original"])
    }
}

@main
struct UIStateTests {
    @MainActor static func main() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("SYDownload-state-\(UUID())")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let context = CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        let image = context.makeImage()!
        for name in ["2024-02-29_12.34.56_08.jpg", "2024-02-29_12.34.56_09.jpg"] {
            let dest = CGImageDestinationCreateWithURL(root.appendingPathComponent(name) as CFURL, "public.jpeg" as CFString, 1, nil)!
            CGImageDestinationAddImage(dest, image, nil)
            precondition(CGImageDestinationFinalize(dest))
        }
        let sub = root.appendingPathComponent("EXIF 输出")
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)
        try fm.copyItem(at: root.appendingPathComponent("2024-02-29_12.34.56_08.jpg"), to: sub.appendingPathComponent("copy.jpg"))
        let shallow = try PhotoLibraryService.scan(folder: root)
        let recursive = try PhotoLibraryService.scan(folder: root, includesSubfolders: true)
        precondition(shallow.totalCount == 2 && recursive.totalCount == 3, "Photo counts: \(shallow.totalCount), \(recursive.totalCount)")

        let exif = ExifEditorModel()
        exif.open(root)
        try await wait(exif)
        precondition(exif.canRun && exif.readyCount == 2)
        let excluded = exif.plans[1].id
        exif.selected.remove(excluded)
        exif.options.make = "Canon"
        exif.refresh()
        try await wait(exif)
        precondition(!exif.selected.contains(excluded) && exif.readyCount == 1)
        exif.options.secondsSource = .suffix
        exif.refresh()
        exif.cancel()
        precondition(!exif.busy && !exif.canRun)
        exif.run()
        precondition(!exif.processing && exif.outcomes.isEmpty && exif.resultFolder == nil)
        exif.refresh()
        try await wait(exif)
        precondition(exif.canRun && exif.plans[0].timestamp == "2024:02:29 12:34:08")

        let suite = "SYDownload-state-tests-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let bridge = SettingsBridge()
        let app = AppModel(userDefaults: defaults, bridgeSend: { await bridge.send($0) })
        await app.loadEngineSettings()
        precondition(app.hasLoadedEngineSettings)
        let saved = app.xhsSettings.folderName
        app.selection = .settings
        app.xhsSettings.folderName = "Unsaved"
        app.xhsSettingsDirty = true
        app.requestSelection(.download)
        await bridge.fail()
        await app.discardUnsavedSettingsAndContinue()
        precondition(app.xhsSettings.folderName == saved && !app.hasUnsavedSettings && app.selection == .download)
        let unloaded = AppModel(userDefaults: defaults, bridgeSend: { await bridge.send($0) })
        await unloaded.loadEngineSettings()
        unloaded.selection = .settings
        unloaded.xhsSettingsDirty = true
        unloaded.requestSelection(.download)
        await unloaded.discardUnsavedSettingsAndContinue()
        precondition(!unloaded.hasLoadedEngineSettings && unloaded.hasUnsavedSettings && unloaded.selection == .settings)

        let originalDefault = app.outputDirectory
        let failed = DownloadTaskItem(title: "fixture", platform: .xiaohongshu, sourceURL: "https://xhslink.com/fixture", state: .failed, outputDirectory: "/original")
        app.tasks = [failed]
        app.changeTaskDestination(failed.id, to: "/changed")
        precondition(app.tasks[0].outputDirectory == "/changed" && app.outputDirectory == originalDefault)
        let request = BridgeRequest(command: "download", folderName: "Selected")
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as! [String: Any]
        precondition(json["folderName"] as? String == "Selected")
        let clock = BridgeTimeoutClock(startTime: 0)
        clock.setWaiting(true, at: 0.25)
        precondition(clock.elapsed(at: 900) == 0.25)
        clock.setWaiting(false, at: 900)
        precondition(clock.elapsed(at: 901) == 1.25)
        print("PASS: photo scope, EXIF selection/cancel/reload, saved settings restore, failed initial load, task-only destination, immutable bridge folder")
    }

    @MainActor static func wait(_ model: ExifEditorModel) async throws {
        for _ in 0..<500 where model.busy { try await Task.sleep(for: .milliseconds(10)) }
        precondition(!model.busy)
    }
}
