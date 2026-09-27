// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Metka",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Metka", path: "Sources/Metka"),
        .testTarget(name: "MetkaTests", dependencies: ["Metka"], path: "Tests/MetkaTests"),
    ]
)
