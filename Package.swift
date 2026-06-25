// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "cliptool-tests",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(name: "JanetKit", path: "JanetKit"),
        .package(url: "https://github.com/LebJe/TOMLKit", from: "0.6.0"),
    ],
    targets: [
        .testTarget(
            name: "CliptoolTests",
            dependencies: ["JanetKit", "TOMLKit"],
            path: ".",
            sources: [
                "Tests/CliptoolTests/RuleEngineTests.swift",
                "Tests/CliptoolTests/SnoozeStateTests.swift",
                "Tests/CliptoolTests/ConfigMigratorTests.swift",
                "cliptool/RuleEngine.swift",
                "cliptool/RuleConfig.swift",
                "cliptool/JanetBridge.swift",
                "cliptool/SnoozeState.swift",
                "cliptool/ConfigMigrator.swift",
            ]
        ),
    ]
)
