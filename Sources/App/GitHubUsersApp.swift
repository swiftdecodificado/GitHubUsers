import GitHubAPI
import SwiftUI

@main
struct GitHubUsersApp: App {
    private let service: any GitHubClientProtocol
    private let images: GitHubImageCache

    init() {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            let offline = arguments.contains("-UITEST_MOCK")
            let stateIndex = arguments.firstIndex(of: "-UITEST_STATE")
            let testState = stateIndex.flatMap {
                arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil
            }

            service = offline ? PreviewGitHubClient(
                initialError: testState == "error",
                detailRefreshError: testState == "detail-refresh-error",
            ) : GitHubClient()
            images = GitHubImageCache(offline: offline)
        #else
            service = GitHubClient()
            images = GitHubImageCache()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(service: service)
                .environment(\.imageCache, images)
        }
    }
}

#if DEBUG
    #Preview("App") {
        AppRootView(service: PreviewGitHubClient())
            .environment(\.imageCache, GitHubImageCache(offline: true))
    }
#endif
