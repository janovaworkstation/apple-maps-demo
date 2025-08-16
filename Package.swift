// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AudioTourDependencies",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AudioTourDependencies",
            targets: ["AudioTourDependencies"]),
    ],
    dependencies: [
        // OpenAI Swift Client for LLM integration
        .package(url: "https://github.com/MacPaw/OpenAI.git", from: "0.2.9"),
        
        // Network Reachability monitoring
        .package(url: "https://github.com/ashleymills/Reachability.swift.git", from: "5.2.3"),
        
        // AsyncLocationKit for modern location handling
        .package(url: "https://github.com/AsyncSwift/AsyncLocationKit.git", from: "1.6.4"),
        
        // Alamofire for advanced networking (optional, for API calls)
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.1"),
        
        // KeychainAccess for secure API key storage
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
        
        // SwiftLog for logging
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.4"),
        
        // Lottie for animations (optional, for better UI)
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.4.3")
    ],
    targets: [
        .target(
            name: "AudioTourDependencies",
            dependencies: [
                .product(name: "OpenAI", package: "OpenAI"),
                .product(name: "Reachability", package: "Reachability.swift"),
                .product(name: "AsyncLocationKit", package: "AsyncLocationKit"),
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Lottie", package: "lottie-spm")
            ]
        ),
        .testTarget(
            name: "AudioTourDependenciesTests",
            dependencies: ["AudioTourDependencies"]
        ),
    ]
)