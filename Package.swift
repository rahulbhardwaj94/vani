// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Vani",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Fork = upstream v1.0.0 + the promptTokens fix from their open
        // PR #497 (decode loop aborted on EOT sampled during prompt
        // prefill → empty transcripts, their issue #501). Prompt biasing
        // (vocabulary → decoder) depends on it. Drop the fork and repin
        // upstream once the PR merges.
        .package(url: "https://github.com/rahulbhardwaj94/argmax-oss-swift.git",
                 revision: "fee9e193168234b15432d89bf5928196c01b1831"),
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
        // The real speech engine (WhisperKit wrapper), shared by the app
        // and the regression harness so tests exercise production code.
        .target(
            name: "VaniSTT",
            dependencies: [
                "VaniCore",
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
            ],
            path: "Sources/VaniSTT",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "Vani",
            dependencies: [
                "VaniCore",
                "VaniSTT",
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "Sources/Vani",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        // Regression harness: runs synthetic + recorded fixtures through the
        // real engine and text pipeline, scores WER, compares to baseline.
        // Run via ./scripts/regress.sh.
        .executableTarget(
            name: "VaniRegress",
            dependencies: ["VaniCore", "VaniSTT"],
            path: "Sources/VaniRegress",
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
