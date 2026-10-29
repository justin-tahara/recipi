// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RecipiKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "RecipiKit", targets: ["RecipiKit"]),
        .library(name: "RecipiDesign", targets: ["RecipiDesign"]),
    ],
    targets: [
        .target(name: "RecipiKit"),
        // Colors, type, motion and small components shared by the app and
        // the share extension. SwiftUI only; no models or app logic.
        .target(name: "RecipiDesign"),
        .testTarget(
            name: "RecipiKitTests",
            dependencies: ["RecipiKit", "RecipiDesign"],
            // Hand-written pages reproducing real recipe-site markup.
            resources: [.copy("Fixtures")]
        ),
    ]
)
