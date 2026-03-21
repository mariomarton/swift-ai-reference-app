// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LlamaBinary",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LlamaBinary",
            targets: ["LlamaFramework"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "LlamaFramework",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b8843/llama-b8843-xcframework.zip",
            checksum: "7509cf3395762c38d3eca1b6b382e00a31a5873141942466e164cd607ed56c35"
        )
    ]
)
