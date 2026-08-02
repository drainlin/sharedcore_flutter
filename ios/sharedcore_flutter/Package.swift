// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "sharedcore_flutter",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "sharedcore-flutter",
            type: .dynamic,
            targets: ["sharedcore_flutter"]
        )
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .binaryTarget(
            name: "SharedCoreRustBinary",
            path: "../Frameworks/sharedcore_flutter.xcframework"
        ),
        .target(
            name: "sharedcore_flutter_linker",
            dependencies: ["SharedCoreRustBinary"],
            publicHeadersPath: "include"
        ),
        .target(
            name: "sharedcore_flutter",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "sharedcore_flutter_linker"
            ]
        )
    ]
)
