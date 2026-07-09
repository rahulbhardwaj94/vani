// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Vani",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.0.0"),
        // Pinned: 1.16.0+ uses #Preview, which requires Xcode's PreviewsMacros
        // plugin and fails to build with Command Line Tools alone.
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", exact: "1.15.0"),
    ],
    targets: [
        // Pure text-pipeline logic (no AppKit/WhisperKit) — unit-testable.
        .target(
            name: "VaniCore",
            path: "Sources/VaniCore",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "Vani",
            dependencies: [
                "VaniCore",
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "Sources/Vani",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        // Plain executable, not .testTarget: Command Line Tools ship neither
        // XCTest nor swift-testing, so `swift test` can't run without Xcode.
        // Run via ./scripts/test.sh.
        .executableTarget(
            name: "VaniTestRunner",
            dependencies: ["VaniCore"],
            path: "Tests/VaniTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
