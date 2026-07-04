// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LokVaani",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.0.0"),
        // Pinned: 1.16.0+ uses #Preview, which requires Xcode's PreviewsMacros
        // plugin and fails to build with Command Line Tools alone.
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", exact: "1.15.0"),
    ],
    targets: [
        .executableTarget(
            name: "LokVaani",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "Sources/LokVaani",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
