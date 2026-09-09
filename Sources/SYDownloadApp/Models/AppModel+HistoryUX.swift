#if canImport(SwiftUI)
import SwiftUI

extension AppModel {
    /// Loads a history URL for another download without mutating the user's default output directory.
    func prepareHistoryRedownload(_ item: HistoryItem) {
        clearInput()
        input = item.sourceURL
        detectLocally()
        selection = .download
        status = "已载入历史链接，可重新检查"
    }
}
#endif
