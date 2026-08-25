// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "AgentSpace",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AgentSpace", targets: ["AgentSpace"])
    ],
    targets: [
        .executableTarget(
            name: "AgentSpace",
            path: "Sources/AgentSpace"
        ),
        .testTarget(
            name: "AgentSpaceTests",
            dependencies: ["AgentSpace"],
            path: "Tests/AgentSpaceTests"
        )
    ]
)
