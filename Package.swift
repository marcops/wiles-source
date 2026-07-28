// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wiles",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Wiles",
            path: "Sources/Wiles",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
