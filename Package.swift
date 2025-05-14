// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let package = Package(
    name: "AssetsConstantPlugin",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .plugin(
            name: "AssetsConstantPlugin",
            targets: ["AssetsConstantPlugin"]
        ),
        .library(
            name: "Example",
            targets: ["Example"]
        )
    ],
    targets: [
        .plugin(
            name: "AssetsConstantPlugin",
            capability: .buildTool(),
            path: "Plugins/AssetsConstantPlugin"
        ),
        .target(
            name: "Example",
            dependencies: [],
            path: "Example/Sources",
            resources: [
                .process("Resources")
            ],
            plugins: [
                .plugin(name: "AssetsConstantPlugin")
            ]
        )
    ]
)
