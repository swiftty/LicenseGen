// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LicenseGen",
    products: [
        .executable(name: "licensegen",
                    targets: ["licensegen"]),
        .library(name: "LicenseGenKit",
                 targets: ["LicenseGenKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.4.0"),
    ],
    targets: [
        .target(name: "licensegen",
                dependencies: [
                    "LicenseGenKit",
                    .product(name: "ArgumentParser", package: "swift-argument-parser")
                ]),
        .target(name: "LicenseGenKit",
                dependencies: []),
        .testTarget(name: "LicenseGenKitTests",
                    dependencies: ["LicenseGenKit"]),
    ]
)
