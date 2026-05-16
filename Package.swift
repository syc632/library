// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LibrarySeatWidget",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LibrarySeatWidget", targets: ["LibrarySeatWidget"])
    ],
    targets: [
        .executableTarget(
            name: "LibrarySeatWidget",
            path: "Sources/LibrarySeatWidget"
        )
    ]
)
