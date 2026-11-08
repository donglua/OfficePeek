// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OfficePeek",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OfficePeekKit",
            targets: ["OfficePeekKit"]
        ),
        .executable(
            name: "OfficePeek",
            targets: ["OfficePeek"]
        )
    ],
    dependencies: [
        .package(path: "../JZOfficeAndroid/viewer-macos")
    ],
    targets: [
        .target(
            name: "OfficePeekKit",
            dependencies: [
                .product(name: "JZOffice", package: "viewer-macos")
            ],
            path: "Sources/OfficePeekKit"
        ),
        .executableTarget(
            name: "OfficePeek",
            dependencies: [
                "OfficePeekKit",
                .product(name: "JZOffice", package: "viewer-macos")
            ],
            path: "Sources/OfficePeek"
        ),
        .testTarget(
            name: "OfficePeekTests",
            dependencies: [
                "OfficePeekKit",
                .product(name: "JZOffice", package: "viewer-macos")
            ],
            path: "Tests/OfficePeekTests"
        )
    ]
)
