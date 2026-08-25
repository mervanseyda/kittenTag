// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "kittenTag",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "kittenTag", targets: ["KittenTag"])
    ],
    dependencies: [
        .package(url: "https://github.com/ryanfrancesconi/spfk-metadata.git", exact: "1.4.5")
    ],
    targets: [
        .executableTarget(
            name: "KittenTag",
            dependencies: [.product(name: "SPFKMetadata", package: "spfk-metadata")],
            path: "Sources/KittenTag",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "KittenTagTests",
            dependencies: ["KittenTag"],
            path: "Tests/KittenTagTests"
        )
    ],
    cxxLanguageStandard: .cxx20
)
