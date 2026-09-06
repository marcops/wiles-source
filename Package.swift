// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wiles",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Wiles", targets: ["Wiles"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.2.1"),
        .package(url: "https://github.com/marcops/git-beacon-mac.git", from: "0.0.4")
    ],
    targets: [
        .executableTarget(
            name: "Wiles",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "GitBeacon", package: "git-beacon-mac")
            ],
            path: "Sources/Wiles",
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "WilesTests",
            dependencies: [
                "Wiles",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Tests/WilesTests")
    ])
