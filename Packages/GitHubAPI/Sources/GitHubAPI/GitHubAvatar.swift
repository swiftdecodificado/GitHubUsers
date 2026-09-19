import Foundation

public extension GitHubUser {
    func avatarURL(size: Int) -> URL {
        avatarURL.githubAvatarURL(size: size)
    }
}

public extension GitHubUserDetail {
    func avatarURL(size: Int) -> URL {
        avatarURL.githubAvatarURL(size: size)
    }
}

public extension URL {
    func githubAvatarURL(size: Int) -> URL {
        guard var parts = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }

        var query = (parts.queryItems ?? []).filter { $0.name != "s" }
        query.append(URLQueryItem(name: "s", value: String(size)))
        parts.queryItems = query
        return parts.url ?? self
    }
}
