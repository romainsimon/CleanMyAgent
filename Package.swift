// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "CleanMyAgent",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CleanMyAgent", targets: ["CleanMyAgentCore"])
    ],
    targets: [
        .executableTarget(
            name: "CleanMyAgentCore",
            path: "Sources/CleanMyAgentCore",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CleanMyAgentCoreTests",
            dependencies: ["CleanMyAgentCore"],
            path: "Tests/CleanMyAgentCoreTests"
        )
    ]
)
