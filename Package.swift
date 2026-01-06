// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "whisper-streaming-benchmark",
    platforms: [
        .macOS(.v14)  // Requires Sonoma+ for latest WhisperKit optimizations
    ],
    products: [
        .executable(name: "streaming-benchmark", targets: ["StreamingBenchmark"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "StreamingBenchmark",
            dependencies: [
                "WhisperKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
