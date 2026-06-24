// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "JanetKit",
    products: [
        .library(name: "JanetKit", targets: ["JanetKit"]),
    ],
    targets: [
        .target(
            name: "CJanet",
            path: "Sources/CJanet",
            sources: ["janet.c", "janet_extensions.c"],
            publicHeadersPath: ".",
            cSettings: [
                .define("JANET_BUILD_TYPE", to: "release"),
                .define("JANET_SINGLE_AMALGAMATION"),
            ]
        ),
        .target(
            name: "JanetKit",
            dependencies: ["CJanet"],
            path: "Sources/JanetKit"
        ),
        .testTarget(
            name: "JanetKitTests",
            dependencies: ["JanetKit"],
            path: "Tests/JanetKitTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
