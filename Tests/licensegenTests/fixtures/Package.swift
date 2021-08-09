// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "example",
    platforms: [.iOS(.v14)],
    products: [
        .executable(name: "example-exe",
                    targets: ["example"]),
        .library(name: "example",
                 targets: ["example"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git",
                 from: "8.5.0")
    ],
    targets: [
        .target(name: "example",
                dependencies: [
                    .product(name: "FirebaseAnalytics",
                             package: "firebase-ios-sdk"),
                    .product(name: "FirebaseAppDistribution",
                             package: "firebase-ios-sdk")
                ])
    ]
)
