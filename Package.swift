// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Renamer",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Renamer",
            path: "Sources",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "RenamerTests",
            dependencies: ["Renamer"],
            path: "Tests"
        )
    ]
)
