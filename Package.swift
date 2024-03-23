// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LicenseGen",
    platforms: [.macOS(.v11)],
    products: [
        .executable(
            name: "licensegen",
            targets: ["licensegen"]),
        .library(
            name: "LicenseGenKit",
            targets: ["LicenseGenKit"])
    ],
    dependencies: [
//        .package(
//            url: "https://github.com/apple/swift-package-manager",
//            revision: "swift-5.7.1-RELEASE"),

        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.3.1"),

        .package(
            url: "https://github.com/jpsim/Yams.git",
            from: "5.1.0"),

        .package(
            url: "https://github.com/apple/swift-log.git",
            from: "1.5.4"),

        .package(
            url: "https://github.com/apple/swift-tools-support-core.git",
            from: "0.6.1")
    ],
    targets: [
        .executableTarget(
            name: "licensegen",
            dependencies: [
                "LicenseGenCommand"
            ]),

        // MARK: -
        .target(
            name: "LicenseGenEntity",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ]),

        .target(
            name: "LicenseGenSwiftPMProxy",
            dependencies: [
                "LicenseGenEntity"
            ]),

        .target(
            name: "LicenseGenCommand",
            dependencies: [
                "LicenseGenKit",
                "Yams",
                .product(name: "ArgumentParser",
                         package: "swift-argument-parser")
            ]),
        .target(
            name: "LicenseGenKit",
            dependencies: [
                "LicenseGenEntity",
                "LicenseGenSwiftPMProxy",
                .product(name: "Logging", package: "swift-log")
            ]),

        .testTarget(
            name: "licensegenTests",
            dependencies: ["licensegen"],
            resources: [.process("fixtures")]),
        .testTarget(
            name: "LicenseGenCommandTests",
            dependencies: [
                "LicenseGenCommand",
                .product(name: "SwiftToolsSupport-auto",
                         package: "swift-tools-support-core"),
                .product(name: "TSCTestSupport",
                         package: "swift-tools-support-core")
            ]),
        .testTarget(
            name: "LicenseGenKitTests",
            dependencies: [
                "LicenseGenKit",
                .product(name: "SwiftToolsSupport-auto",
                         package: "swift-tools-support-core"),
                .product(name: "TSCTestSupport",
                         package: "swift-tools-support-core")
            ],
            resources: [.process("fixtures")]),

        .testTarget(
            name: "LicenseGenSwiftPMProxyTests",
            dependencies: ["LicenseGenSwiftPMProxy"])
    ]
)
