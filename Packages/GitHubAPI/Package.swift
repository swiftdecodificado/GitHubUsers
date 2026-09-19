// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "GitHubAPI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "GitHubAPI", targets: ["GitHubAPI"])],
    targets: [
        .target(name: "GitHubAPI"),
        .testTarget(
            name: "GitHubAPITests",
            dependencies: ["GitHubAPI"]
        )
    ],
    swiftLanguageModes: [.v6]
)
