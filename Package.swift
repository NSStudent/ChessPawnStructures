// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ChessPawnStructures",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "ChessPawnStructures", targets: ["ChessPawnStructures"]),
    ],
    targets: [
        .target(
            name: "ChessPawnStructures",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Herramienta de desarrollo: medir `classify` y comparar con la referencia en Python.
        .executableTarget(
            name: "pawn-structures-tool",
            dependencies: ["ChessPawnStructures"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "ChessPawnStructuresTests",
            dependencies: ["ChessPawnStructures"],
            resources: [.copy("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
