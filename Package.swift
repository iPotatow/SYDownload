// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SYDownload",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SYDownloadCore", targets: ["XDownloaderCore"]),
        .executable(name: "SYDownload", targets: ["XDownloaderApp"]),
    ],
    targets: [
        .target(name: "XDownloaderCore"),
        .executableTarget(
            name: "XDownloaderApp",
            dependencies: ["XDownloaderCore"]
        ),
        .testTarget(
            name: "XDownloaderCoreTests",
            dependencies: ["XDownloaderCore"]
        ),
    ]
)
