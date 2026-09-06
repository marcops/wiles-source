// swift-tools-version: 6.0
import PackageDescription

// Standalone AX-driven UI test runner for Wiles. Deliberately its own package so the app's
// Package.swift and Sources/Wiles/ stay untouched — this only drives Wiles.app from the outside
// via the macOS Accessibility API (AXUIElement), never links against it.
let package = Package(
    name: "UITestRunner",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "uitestrunner",
            path: "Sources/uitestrunner")
    ])
