// swift-tools-version:5.7.3
import PackageDescription


let package = Package(
    name: "swiftlintbot",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "swiftlintbot", targets: ["SwiftLintBot"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.2"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.0.0"),
        .package(url: "https://github.com/realm/SwiftLint", from: "0.52.2")
    ],
    targets: [
        .executableTarget(
            name: "SwiftLintBot",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "ShellOut", package: "ShellOut"),
                .product(name: "SwiftLintFramework", package: "SwiftLint")
            ],
            resources: [
                .copy("Resources/swiftlint.yml")
            ]
        )
    ]
)
