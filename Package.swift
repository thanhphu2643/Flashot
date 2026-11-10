// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Flashot",
    platforms: [.macOS(.v14)],
    targets: [
        .systemLibrary(name: "CShotCore"),
        .executableTarget(name: "Flashot", dependencies: ["CShotCore"]),
    ]
)
