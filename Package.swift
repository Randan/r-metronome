// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "r-metronome",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "RMetronomeCore", targets: ["RMetronomeCore"]),
        .executable(name: "r-metronome", targets: ["RMetronomeCLI"]),
        .executable(name: "r-metronome-app", targets: ["RMetronomeApp"])
    ],
    targets: [
        .target(
            name: "RMetronomeCore",
            path: "Sources/RMetronomeCore"
        ),
        .executableTarget(
            name: "RMetronomeCLI",
            dependencies: ["RMetronomeCore"],
            path: "Sources/RMetronomeCLI"
        ),
        .executableTarget(
            name: "RMetronomeApp",
            dependencies: ["RMetronomeCore"],
            path: "Sources/RMetronomeApp"
        ),
        .testTarget(
            name: "RMetronomeCoreTests",
            dependencies: ["RMetronomeCore"],
            path: "Tests/RMetronomeCoreTests"
        )
    ]
)
