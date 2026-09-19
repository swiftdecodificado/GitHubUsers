import Foundation
import GitHubAPI

#if DEBUG
    /// Deterministic, entirely offline dependencies for previews and UI automation.
    actor PreviewGitHubClient: GitHubClientProtocol {
        private var initialError: Bool
        private let detailRefreshError: Bool
        private var detailCalls = 0

        init(initialError: Bool = false, detailRefreshError: Bool = false) {
            self.initialError = initialError
            self.detailRefreshError = detailRefreshError
        }

        func users(since: Int, perPage: Int) async throws -> [GitHubUser] {
            if initialError {
                initialError = false
                throw GitHubAPIError.network
            }

            guard since < 90 else {
                return []
            }

            return ((since + 1) ... (since + perPage)).map { id in
                let login = id == 1 ? "mojombo" : "developer\(id)"
                let name = id == 1 ? "Tom Preston-Werner" : "Developer \(id)"

                return GitHubUser(
                    id: id,
                    login: login,
                    name: name,
                    avatarURL: URL(string: "https://avatars.githubusercontent.com/u/\(id)?v=4")!,
                    htmlURL: URL(string: "https://github.com/\(login)")!,
                )
            }
        }

        func detail(login: String) async throws -> GitHubUserDetail {
            detailCalls += 1
            if detailRefreshError, detailCalls == 2 {
                throw GitHubAPIError.network
            }
            return GitHubUserDetail(
                id: 1,
                login: login,
                name: login == "mojombo" ? "Tom Preston-Werner" : login,
                avatarURL: URL(string: "https://avatars.githubusercontent.com/u/1?v=4")!,
                bio: detailRefreshError && detailCalls > 2
                    ? "Updated profile after retry."
                    : "Building tools for people who build things.",
                company: "GitHub",
                location: "San Francisco",
                blog: "https://github.com",
                twitterUsername: "mojombo",
                publicRepos: 100,
                followers: 23100,
                following: 11,
                createdAt: Date(timeIntervalSince1970: 1_192_857_859),
                htmlURL: URL(string: "https://github.com/\(login)")!,
            )
        }
    }
#endif
