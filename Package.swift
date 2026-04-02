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
        .package(url: "https://github.com/mchakravarty/CodeEditorView.git", from: "0.12.0"),
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
