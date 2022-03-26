// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LicenseGen",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "licensegen",
                    targets: ["licensegen"]),
        .library(name: "LicenseGenKit",
                 targets: ["LicenseGenKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser",
                 from: "1.0.0"),

        .package(url: "https://github.com/jpsim/Yams",
                 from: "4.0.0"),

        .package(url: "https://github.com/apple/swift-log",
                 from: "1.0.0"),

        .package(url: "https://github.com/apple/swift-tools-support-core",
                 from: "0.2.0")
    ],
    targets: [
        .target(name: "licensegen",
                dependencies: [
                    "LicenseGenCommand"
                ]),
        .target(name: "LicenseGenCommand",
                dependencies: [
                    "LicenseGenKit",
                    "Yams",
                    .product(name: "ArgumentParser",
                             package: "swift-argument-parser")
                ]),
        .target(name: "LicenseGenKit",
                dependencies: [
                    .product(name: "Logging", package: "swift-log")
                ]),

        .testTarget(name: "licensegenTests",
                    dependencies: ["licensegen"],
                    resources: [.process("fixtures")]),
        .testTarget(name: "LicenseGenCommandTests",
                    dependencies: [
                        "LicenseGenCommand",
                        .product(name: "SwiftToolsSupport-auto",
                                 package: "swift-tools-support-core"),
                        .product(name: "TSCTestSupport",
                                 package: "swift-tools-support-core")
                    ]),
        .testTarget(name: "LicenseGenKitTests",
                    dependencies: [
                        "LicenseGenKit",
                        .product(name: "SwiftToolsSupport-auto",
                                 package: "swift-tools-support-core"),
                        .product(name: "TSCTestSupport",
                                 package: "swift-tools-support-core")
                    ],
                    resources: [.process("fixtures")])
    ]
)
