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
            exclude: [
                // The nested package has its own Package.swift; don't let SPM
                // pull its sources into this target.
                "JanetKit",
                // Build artifacts (gitignored but present locally).
                "cliptool.app",
                "cliptool.zip",
                // App-only sources intentionally not compiled into the test
                // target (they pull in the full AppKit life-cycle).
                "cliptool/AppDelegate.swift",
                "cliptool/cliptoolApp.swift",
                "cliptool/ClipboardMonitor.swift",
                // App resources / non-Swift files that aren't test resources.
                "cliptool/Assets.xcassets",
                "cliptool/Info.plist",
                "build.sh",
                "ExportOptions.plist",
                "README.md",
            ],
            sources: [
                "Tests/CliptoolTests/RuleEngineTests.swift",
                "Tests/CliptoolTests/SnoozeStateTests.swift",
                "Tests/CliptoolTests/ConfigMigratorTests.swift",
                "Tests/CliptoolTests/ConfigWatcherTests.swift",
                "Tests/CliptoolTests/StatusMenuBuilderTests.swift",
                "cliptool/RuleEngine.swift",
                "cliptool/RuleConfig.swift",
                "cliptool/JanetBridge.swift",
                "cliptool/SnoozeState.swift",
                "cliptool/ConfigMigrator.swift",
                "cliptool/ConfigWatcher.swift",
                "cliptool/StatusMenuBuilder.swift",
            ]
        ),
    ]
)
