// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SYDownload",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SYDownloadCore", targets: ["SYDownloadCore"]),
        .executable(name: "SYDownload", targets: ["SYDownloadApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0"),
    ],
    targets: [
        .target(name: "SYDownloadCore"),
        .executableTarget(
            name: "SYDownloadApp",
            dependencies: ["SYDownloadCore", .product(name: "Sparkle", package: "Sparkle", condition: .when(platforms: [.macOS]))],
            exclude: ["Resources"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"], .when(platforms: [.macOS]))]
        ),
        .testTarget(
            name: "SYDownloadCoreTests",
            dependencies: ["SYDownloadCore"]
        ),
        .testTarget(
            name: "SYDownloadAppTests",
            dependencies: ["SYDownloadApp"]
        ),
    ]
)
