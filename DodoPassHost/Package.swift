// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DodoPassHost",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "DodoPassHost",
            path: ".",
            sources: ["main.swift"]
        )
    ]
)
