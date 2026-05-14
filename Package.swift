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
            name: "SwiftToolkit",
            targets: ["SwiftToolkit"]
        ),
        .library(
            name: "SwiftToolkitUI",
            targets: ["SwiftToolkitUI"]
        ),
        .library(
            name: "SwiftToolkitVideo",
            targets: ["SwiftToolkitVideo"]
        ),
        .library(
            name: "SwiftToolkitImage",
            targets: ["SwiftToolkitImage"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.0.0")
    ],
    targets: [
        .target(
            name: "SwiftToolkit",
            path: "Sources/SwiftToolkit"
        ),
        .target(
            name: "SwiftToolkitUI",
            path: "Sources/SwiftToolkitUI"
        ),
        .target(
            name: "SwiftToolkitVideo",
            dependencies: ["SwiftToolkit", "SwiftToolkitUI"],
            path: "Sources/SwiftToolkitVideo"
        ),
        .target(
            name: "SwiftToolkitImage",
            dependencies: [
                .product(name: "Kingfisher", package: "Kingfisher")
            ],
            path: "Sources/SwiftToolkitImage"
        ),
        .testTarget(
            name: "SwiftToolkitTests",
            dependencies: ["SwiftToolkit"],
            path: "Tests/SwiftToolkitTests"
        )
    ]
)
