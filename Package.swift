// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wiles",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Wiles", targets: ["Wiles"]),
        .executable(name: "WilesTestRunner", targets: ["WilesTestRunner"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.2.1")
    ],
    targets: [
        .target(
            name: "WilesCore",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/Wiles",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "Wiles",
            dependencies: ["WilesCore"],
            path: "Sources/WilesApp"
        ),
        .executableTarget(
            name: "WilesTestRunner",
            dependencies: ["WilesCore"],
            path: "Tests/WilesTests"
        )
    ]
)
