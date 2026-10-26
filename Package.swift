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
        // CoreGraphics is required for CGRect geometry APIs (minX/intersects/etc.).
        .target(
            name: "NotchBarCore",
            linkerSettings: [.linkedFramework("CoreGraphics")]
        ),
        // The menu bar agent app (AppKit + Accessibility).
        .executableTarget(name: "NotchBar", dependencies: ["NotchBarCore"]),
        .testTarget(
            name: "NotchBarCoreTests",
            dependencies: ["NotchBarCore"],
            linkerSettings: [.linkedFramework("CoreGraphics")]
        ),
    ]
)
