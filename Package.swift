// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wiles",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Wiles", targets: ["Wiles"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.2.1")
    ],
    targets: [
        .executableTarget(
            name: "Wiles",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/Wiles",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "WilesTests",
            dependencies: ["Wiles"],
            path: "Tests/WilesTests"
        )
    ]
)
