// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BaseUIKit",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "BaseUIKit",
            targets: ["BaseUIKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/andyfinnell/BaseKit.git", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "BaseUIKit",
            dependencies: [
                .product(name: "BaseKit", package: "BaseKit")
            ]
        ),
        .testTarget(
            name: "BaseUIKitTests",
            dependencies: ["BaseUIKit"]),
    ]
)
