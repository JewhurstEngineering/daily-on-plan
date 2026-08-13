// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OnPlanCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "OnPlanCore", targets: ["OnPlanCore"]),
    ],
    targets: [
        .target(
            name: "OnPlanCore",
            path: "Sources/OnPlanCore"
        ),
        .testTarget(
            name: "OnPlanCoreTests",
            dependencies: ["OnPlanCore"],
            path: "Tests/OnPlanCoreTests"
        ),
    ]
)
