#if canImport(AppKit)
import AppKit

@MainActor
final class SYDownloadAppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    private var awaitingDecision = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !awaitingDecision else { return .terminateLater }
        guard let model, model.hasUnsavedSettings else { return .terminateNow }
        awaitingDecision = true
        // AppKit must receive .terminateLater before we reply. Keep this prompt
        // at application scope so quitting also works after the last window closes.
        Task { @MainActor [self] in
            let alert = NSAlert()
            alert.messageText = "保存设置更改？"
            alert.informativeText = "小红书或抖音设置还有未保存的更改。"
            alert.addButton(withTitle: "保存")
            alert.addButton(withTitle: "放弃更改")
            alert.addButton(withTitle: "取消")
            let decision = alert.runModal()
            let shouldQuit = await resolveTerminationDecision(decision, model: model)
            awaitingDecision = false
            sender.reply(toApplicationShouldTerminate: shouldQuit)
        }
        return .terminateLater
    }

    func resolveTerminationDecision(_ decision: NSApplication.ModalResponse, model: AppModel) async -> Bool {
        model.pendingTermination = true
        defer { model.pendingTermination = false }
        switch decision {
        case .alertFirstButtonReturn:
            return await model.saveUnsavedSettingsAndContinue()
        case .alertSecondButtonReturn:
            await model.discardUnsavedSettingsAndContinue()
            return true
        default:
            return false
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.cancelAllActiveTasks()
    }
}
#endif
