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
        .package(name: "Firebase",
                 url: "https://github.com/firebase/firebase-ios-sdk.git",
                 from: "8.5.0"),

        .package(url: "https://github.com/ReactiveX/RxSwift.git",
                 from: "6.2.0")
    ],
    targets: [
        .target(name: "example",
                dependencies: [
                    .product(name: "FirebaseAnalytics",
                             package: "Firebase"),
                    .product(name: "FirebaseAppDistribution",
                             package: "Firebase"),

                    "RxSwift",
                    .product(name: "RxCocoa",
                             package: "RxSwift")
                ])
    ]
)
