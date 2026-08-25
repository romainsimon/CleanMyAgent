// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "CleanMyAgent",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CleanMyAgent", targets: ["AgentSpace"])
    ],
    targets: [
        .executableTarget(
            name: "AgentSpace",
            path: "Sources/AgentSpace",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AgentSpaceTests",
            dependencies: ["AgentSpace"],
            path: "Tests/AgentSpaceTests"
        )
    ]
)
