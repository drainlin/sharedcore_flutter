// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "sharedcore_flutter",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "sharedcore-flutter",
            type: .static,
            targets: ["sharedcore_flutter"]
        )
    ],
    dependencies: [],
    targets: [
        .binaryTarget(
            name: "SharedCoreRustBinary",
            path: "Frameworks/SharedCoreRustBinary.xcframework"
        ),
        .target(
            name: "sharedcore_flutter_linker",
            dependencies: ["SharedCoreRustBinary"],
            publicHeadersPath: "include"
        ),
        .target(
            name: "sharedcore_flutter",
            dependencies: [
                "sharedcore_flutter_linker"
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
