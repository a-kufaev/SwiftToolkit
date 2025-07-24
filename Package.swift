// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftToolkit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "SwiftToolkitUI",
            targets: ["SwiftToolkitUI"]
        )
    ],
    targets: [
        .target(
            name: "SwiftToolkitUI",
            path: "Sources/SwiftToolkitUI"
        )
    ]
)
