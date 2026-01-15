// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PreviewAgent",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "PreviewAgent",
            targets: ["PreviewAgent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.23.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.25.0"), // Required for gRPC-Swift
    ],
    targets: [
        // Target for the generated Protobuf code
        .target(
            name: "Proto",
            dependencies: [
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "GRPC", package: "grpc-swift"),
            ],
            path: "Sources/Proto",
            exclude: ["README.md"] // Explicitly manage sources or let it pick up generated files later
        ),
        // Main Agent Executable
        .executableTarget(
            name: "PreviewAgent",
            dependencies: [
                "Proto",
                .product(name: "GRPC", package: "grpc-swift"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "Sources/PreviewAgent"
        ),
    ]
)
