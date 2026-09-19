// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "GitHubUsers",
    defaultLocalization: "pt-BR",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "GitHubUsers", targets: ["GitHubUsers"])],
    dependencies: [.package(path: "Packages/GitHubAPI")],
    targets: [
        // The package exposes presentation logic for macOS tests. The iOS app
        // and its resources are built by the Xcode project.
        .target(
            name: "GitHubUsers",
            dependencies: [.product(name: "GitHubAPI", package: "GitHubAPI")],
            path: "Sources",
            exclude: [
                "App",
                "Resources",
                "Components",
                "Preview",
                "Features/UsersList/Components",
                "Features/UsersList/UsersListView.swift",
                "Features/UserDetail/Components",
                "Features/UserDetail/UserDetailView.swift"
            ],
            sources: [
                "Support",
                "Features/UsersList/UserPresentation.swift",
                "Features/UsersList/UsersListViewModel.swift",
                "Features/UserDetail/UserDetailViewModel.swift"
            ]
        ),
        .testTarget(
            name: "GitHubUsersTests",
            dependencies: ["GitHubUsers", .product(name: "GitHubAPI", package: "GitHubAPI")],
            path: "Tests",
            resources: [.process("Fixtures")]
        )
    ],
    swiftLanguageModes: [.v6]
)
