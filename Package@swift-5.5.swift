// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
// Only for development checks
//    SwiftSetting.unsafeFlags([
//        "-Xfrontend", "-strict-concurrency=complete",
//        "-Xfrontend", "-warn-concurrency",
//        "-Xfrontend", "-enable-actor-data-race-checks",
//    ])
]

let package = Package(
    name: "RouterBytes",
    platforms: [
        .iOS(.v13),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "RouterBytes",
            targets: ["RouterBytes"]),
        .library(
            name: "RouterBytesAuthentication",
            targets: ["RouterBytesAuthentication"]
        ),
        .library(
            name: "APIMultipart",
            targets: ["APIMultipart"]
        ),
        .library(
            name: "APIServiceMock",
            targets: ["APIServiceMock"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/cleevio/CleevioCore.git", .upToNextMajor(from: .init(2, 1, 7))),
        .package(url: "https://github.com/cleevio/CleevioStorage.git", .upToNextMajor(from: .init(0, 4, 2))),
        .package(url: "https://github.com/apple/swift-collections.git", from: .init(1, 1, 1)),
        .package(url: "https://github.com/apple/swift-http-types.git", from: .init(1, 5, 1)),
    ],
    targets: [
        .target(
            name: "RouterBytes",
            dependencies: [
                .product(name: "CleevioCore", package: "CleevioCore"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "HTTPTypesFoundation", package: "swift-http-types")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "RouterBytesAuthentication",
            dependencies: [
                "RouterBytes",
                "CleevioStorage"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "APIServiceMock",
            dependencies: [
                "RouterBytes",
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "APIMultipart",
            dependencies: [
                "RouterBytes"
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "RouterBytesTests",
            dependencies: [
                "RouterBytes",
                "RouterBytesAuthentication"
            ])
    ]
)
