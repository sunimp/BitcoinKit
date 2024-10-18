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
        .package(url: "https://github.com/sunimp/BitcoinCore.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/sunimp/Hodler.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/sunimp/HDWalletKit.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/sunimp/SWToolKit.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.54.6"),
    ],
    targets: [
        .target(
            name: "BitcoinKit",
            dependencies: [
                "BitcoinCore",
                "Hodler",
                "HDWalletKit",
                "SWToolKit",
            ]
        ),
    ]
)
