// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SYDownload",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SYDownloadCore", targets: ["SYDownloadCore"]),
        .executable(name: "SYDownload", targets: ["SYDownloadApp"]),
    ],
    targets: [
        .target(name: "SYDownloadCore"),
        .executableTarget(
            name: "SYDownloadApp",
            dependencies: ["SYDownloadCore"]
        ),
        .testTarget(
            name: "SYDownloadCoreTests",
            dependencies: ["SYDownloadCore"]
        ),
    ]
)
