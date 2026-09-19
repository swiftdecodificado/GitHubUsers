import Foundation
@testable import GitHubAPI
import Testing

@Test func `avatar URL adds requested size`() throws {
    let user = try GitHubUser(
        id: 1,
        login: "mojombo",
        avatarURL: #require(URL(string: "https://avatars.githubusercontent.com/u/1?v=4")),
        htmlURL: #require(URL(string: "https://github.com/mojombo")),
    )

    #expect(user.avatarURL(size: 200).absoluteString == "https://avatars.githubusercontent.com/u/1?v=4&s=200")
}

@Test func `avatar URL replaces existing size`() throws {
    let detail = try GitHubUserDetail(
        id: 1,
        login: "mojombo",
        name: nil,
        avatarURL: #require(URL(string: "https://avatars.githubusercontent.com/u/1?v=4&s=80")),
        bio: nil,
        company: nil,
        location: nil,
        blog: nil,
        twitterUsername: nil,
        publicRepos: 0,
        followers: 0,
        following: 0,
        createdAt: .now,
        htmlURL: #require(URL(string: "https://github.com/mojombo")),
    )

    #expect(detail.avatarURL(size: 460).absoluteString == "https://avatars.githubusercontent.com/u/1?v=4&s=460")
}

@Test func `blog URL normalizes safe web links`() throws {
    let detail = try GitHubUserDetail(
        id: 1,
        login: "mojombo",
        name: nil,
        avatarURL: #require(URL(string: "https://avatars.githubusercontent.com/u/1?v=4")),
        bio: nil,
        company: nil,
        location: nil,
        blog: "github.com",
        twitterUsername: nil,
        publicRepos: 0,
        followers: 0,
        following: 0,
        createdAt: .now,
        htmlURL: #require(URL(string: "https://github.com/mojombo")),
    )

    #expect(detail.blogURL?.absoluteString == "https://github.com")
    #expect(detail.withBlog("javascript://bad").blogURL == nil)
    #expect(detail.withBlog(" ").blogURL == nil)
}

@Test func `error convenience maps and formats retry state`() {
    #expect(GitHubAPIError.map(URLError(.timedOut)) == .transport(.timedOut))
    #expect(
        GitHubAPIError.map(
            DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad")),
        ) == .decoding,
    )

    let error = GitHubAPIError.rateLimited(resetAt: Date(timeIntervalSince1970: 60))
    #expect(error.resetAt == Date(timeIntervalSince1970: 60))
    #expect(error.remaining(at: Date(timeIntervalSince1970: 0)) == "01:00")
    #expect(error.canRetry(at: Date(timeIntervalSince1970: 60)))
}

private extension GitHubUserDetail {
    func withBlog(_ blog: String?) -> GitHubUserDetail {
        GitHubUserDetail(
            id: id,
            login: login,
            name: name,
            avatarURL: avatarURL,
            bio: bio,
            company: company,
            location: location,
            blog: blog,
            twitterUsername: twitterUsername,
            publicRepos: publicRepos,
            followers: followers,
            following: following,
            createdAt: createdAt,
            htmlURL: htmlURL,
        )
    }
}
