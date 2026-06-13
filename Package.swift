// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Jugada",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Jugada", path: "Sources/Jugada")
    ]
)
