// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "BitcoinKit",
    platforms: [
        .iOS(.v14),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "BitcoinKit",
            targets: ["BitcoinKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/sunimp/BitcoinCore.Swift.git", .upToNextMajor(from: "3.1.0")),
        .package(url: "https://github.com/sunimp/Hodler.Swift.git", .upToNextMajor(from: "2.0.5")),
        .package(url: "https://github.com/sunimp/HDWalletKit.Swift.git", .upToNextMajor(from: "1.3.5")),
        .package(url: "https://github.com/sunimp/WWToolKit.Swift.git", .upToNextMajor(from: "2.1.1")),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.54.0"),
    ],
    targets: [
        .target(
            name: "BitcoinKit",
            dependencies: [
                .product(name: "BitcoinCore", package: "BitcoinCore.Swift"),
                .product(name: "Hodler", package: "Hodler.Swift"),
                .product(name: "HDWalletKit", package: "HDWalletKit.Swift"),
                .product(name: "WWToolKit", package: "WWToolKit.Swift"),
            ]
        ),
    ]
)
