// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "buzzkill",
    platforms: [.macOS(.v12)],
    targets: [
        .target(name: "BuzzkillCore"),
        .executableTarget(name: "buzzkilld", dependencies: ["BuzzkillCore"]),
        .testTarget(name: "BuzzkillCoreTests", dependencies: ["BuzzkillCore"]),
    ]
)
