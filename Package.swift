// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsageBar",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "ClaudeUsageBar",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/ClaudeUsageBar",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "ClaudeUsageBarTests",
            dependencies: ["ClaudeUsageBar"],
            path: "Tests/ClaudeUsageBarTests"
        )
    ]
)
