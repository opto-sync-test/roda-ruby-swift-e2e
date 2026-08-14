// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RubySwiftContract",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "RubySwiftContract", targets: ["RubySwiftContract"])
    ],
    dependencies: [
        .package(path: "vendor/opto-sync-clients/clients/swift")
    ],
    targets: [
        .target(
            name: "RubySwiftContract",
            dependencies: [
                .product(name: "OptoSyncClient", package: "swift")
            ]
        ),
        .testTarget(
            name: "RubySwiftContractTests",
            dependencies: ["RubySwiftContract"]
        )
    ]
)
