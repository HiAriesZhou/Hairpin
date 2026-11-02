// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Hairpin",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Hairpin", targets: ["Hairpin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1"),
    ],
    targets: [
        // Pure, AppKit-free logic: geometry, notch detection, sorting, filtering.
        // CoreGraphics is required for CGRect geometry APIs (minX/intersects/etc.).
        .target(
            name: "HairpinCore",
            linkerSettings: [.linkedFramework("CoreGraphics")]
        ),
        // The menu bar agent app (AppKit + Accessibility).
        .executableTarget(
            name: "Hairpin",
            dependencies: ["HairpinCore", .product(name: "Sparkle", package: "Sparkle")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(
            name: "HairpinCoreTests",
            dependencies: ["HairpinCore"],
            linkerSettings: [.linkedFramework("CoreGraphics")]
        ),
    ]
)
