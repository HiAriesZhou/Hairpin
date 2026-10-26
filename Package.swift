// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Hairpin",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Hairpin", targets: ["Hairpin"]),
    ],
    targets: [
        // Pure, AppKit-free logic: geometry, notch detection, sorting, filtering.
        // CoreGraphics is required for CGRect geometry APIs (minX/intersects/etc.).
        .target(
            name: "HairpinCore",
            linkerSettings: [.linkedFramework("CoreGraphics")]
        ),
        // The menu bar agent app (AppKit + Accessibility).
        .executableTarget(name: "Hairpin", dependencies: ["HairpinCore"]),
        .testTarget(
            name: "HairpinCoreTests",
            dependencies: ["HairpinCore"],
            linkerSettings: [.linkedFramework("CoreGraphics")]
        ),
    ]
)
