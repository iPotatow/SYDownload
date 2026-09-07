// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XDownloaderSpike",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "XDownloaderCore", targets: ["XDownloaderCore"]),
        .executable(name: "XDownloader", targets: ["XDownloaderApp"]),
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
