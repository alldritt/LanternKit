// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LanternKit",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(name: "LanternKit", targets: ["LanternKit"]),
    ],
    dependencies: [
        .package(path: "../Lantern"),
        .package(path: "../CodeEditorView"),
    ],
    targets: [
        .target(
            name: "LanternKit",
            dependencies: [
                .product(name: "Lantern", package: "Lantern"),
                .product(name: "CodeEditorView", package: "CodeEditorView"),
                .product(name: "LanguageSupport", package: "CodeEditorView"),
            ]
        ),
    ]
)
