import GitHubAPI
#if DEBUG
    import Foundation

    extension GitHubUser {
        static let preview = GitHubUser(
            id: 1,
            login: "mojombo",
            name: "Tom Preston-Werner",
            avatarURL: URL(string: "https://avatars.githubusercontent.com/u/1?v=4")!,
            htmlURL: URL(string: "https://github.com/mojombo")!
        )
    }
#endif
