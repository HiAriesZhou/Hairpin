// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NotchBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NotchBar", targets: ["NotchBar"]),
    ],
    targets: [
        // Pure, AppKit-free logic: geometry, notch detection, sorting, filtering.
        .target(name: "NotchBarCore"),
        // The menu bar agent app (AppKit + Accessibility).
        .executableTarget(name: "NotchBar", dependencies: ["NotchBarCore"]),
        .testTarget(name: "NotchBarCoreTests", dependencies: ["NotchBarCore"]),
    ]
)
