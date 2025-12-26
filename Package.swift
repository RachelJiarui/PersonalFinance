// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BudgetInsight",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "BudgetInsight",
            targets: ["BudgetInsight"])
    ],
    dependencies: [
        // No external dependencies needed - SimpleFin uses standard URLSession
    ],
    targets: [
        .target(
            name: "BudgetInsight",
            dependencies: []
        )
    ]
)
