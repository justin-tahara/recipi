// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RecipiKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "RecipiKit", targets: ["RecipiKit"]),
    ],
    targets: [
        .target(name: "RecipiKit"),
        .testTarget(name: "RecipiKitTests", dependencies: ["RecipiKit"]),
    ]
)
