// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "PMJSON",
    products: [
        .library(
            name: "PMJSON",
            targets: ["PMJSON"]),
    ],
    targets: [
        .target(
            name: "PMJSON",
            path: "Sources"),
        .testTarget(
            name: "PMJSONTests",
            dependencies: ["PMJSON"]),
    ]
)
