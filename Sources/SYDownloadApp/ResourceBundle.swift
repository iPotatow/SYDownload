import Foundation

extension Bundle {
    /// SYDownload is assembled as a macOS app bundle by script/package_app.sh.
    /// App resources live in Contents/Resources, so use the main bundle instead
    /// of SwiftPM's generated Bundle.module accessor, which is not relocatable
    /// after installation.
    static var module: Bundle { .main }
}
