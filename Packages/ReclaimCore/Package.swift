// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReclaimCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ReclaimCore", targets: ["ReclaimCore"]),
        .executable(name: "reclaim-scan", targets: ["reclaim-scan"]),
    ],
    targets: [
        .target(name: "ReclaimCore"),
        // Development tool: scans a folder and prints what the app would suggest. Never deletes anything.
        .executableTarget(name: "reclaim-scan", dependencies: ["ReclaimCore"]),
        .testTarget(name: "ReclaimCoreTests", dependencies: ["ReclaimCore"]),
    ]
)
