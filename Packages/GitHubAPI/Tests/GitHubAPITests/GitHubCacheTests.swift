import Foundation
@testable import GitHubAPI
import Testing

struct GitHubCacheTests {
    @Test func `images deduplicate and persist`() async throws {
        let data = Data("image bytes".utf8)
        let server = StubServer([.init(status: 200, data: data)])
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let cache = GitHubImageCache(session: server.session, directory: directory)
        let url = try #require(server.request.url)

        async let first = cache.data(for: url)
        async let second = cache.data(for: url)

        #expect(try await first == data)
        #expect(try await second == data)
        #expect(server.count == 1)
        #expect(try await cache.data(for: url) == data)

        let diskCache = GitHubImageCache(session: server.session, directory: directory)
        #expect(try await diskCache.data(for: url) == data)
        #expect(server.count == 1)
    }

    @Test func `images recover after failure`() async throws {
        let server = StubServer([.init(status: 500), .init(status: 200, data: Data([1]))])
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let cache = GitHubImageCache(session: server.session, directory: directory)
        let url = try #require(server.request.url)

        await #expect(throws: GitHubAPIError.server) {
            try await cache.data(for: url)
        }
        #expect(try await cache.data(for: url) == Data([1]))
        #expect(server.count == 2)
    }

    @Test func `images reject invalid content and oversized responses`() async throws {
        let invalidType = StubServer([
            .init(status: 200, headers: ["Content-Type": "text/plain"], data: Data([1]))
        ])
        let invalidTypeCache = GitHubImageCache(session: invalidType.session)

        await #expect(throws: GitHubAPIError.invalidResponse) {
            try await invalidTypeCache.data(for: #require(invalidType.request.url))
        }

        let oversized = StubServer([
            .init(
                status: 200,
                headers: ["Content-Length": String(20 * 1024 * 1024 + 1)],
                data: Data([1])
            )
        ])
        let oversizedCache = GitHubImageCache(session: oversized.session)

        await #expect(throws: GitHubAPIError.invalidResponse) {
            try await oversizedCache.data(for: #require(oversized.request.url))
        }
    }

    @Test func `images retry only transient transport failures`() async throws {
        let transient = StubServer([
            .init(status: 0, error: URLError(.timedOut)),
            .init(status: 200, data: Data([1]))
        ])
        let transientCache = GitHubImageCache(session: transient.session)
        #expect(try await transientCache.data(for: #require(transient.request.url)) == Data([1]))
        #expect(transient.count == 2)

        let permanent = StubServer([
            .init(status: 0, error: URLError(.cannotFindHost)),
            .init(status: 200, data: Data([1]))
        ])
        let permanentCache = GitHubImageCache(session: permanent.session)
        await #expect(throws: GitHubAPIError.transport(.cannotFindHost)) {
            try await permanentCache.data(for: #require(permanent.request.url))
        }
        #expect(permanent.count == 1)
    }

    @Test func `user cache expiry invalidation and old generation`() async throws {
        let user = try GitHubUser(
            id: 1,
            login: "mojombo",
            avatarURL: #require(URL(string: "https://avatars.githubusercontent.com/u/1?v=4")),
            htmlURL: #require(URL(string: "https://github.com/mojombo"))
        )
        let detail = GitHubUserDetail(
            id: user.id,
            login: user.login,
            name: nil,
            avatarURL: user.avatarURL,
            bio: nil,
            company: nil,
            location: nil,
            blog: nil,
            twitterUsername: nil,
            publicRepos: 0,
            followers: 0,
            following: 0,
            createdAt: .now,
            htmlURL: user.htmlURL
        )

        let cache = GitHubUserCache()
        await cache.store([user], since: 0, generation: 0)
        #expect(await cache.users(since: 0) == [user])

        await cache.invalidate()
        await cache.store([user], since: 0, generation: 0)
        #expect(await cache.users(since: 0) == nil)

        let expired = GitHubUserCache(ttl: -1)
        await expired.store(detail, login: "mojombo", generation: expired.generation)
        #expect(await expired.detail(login: "mojombo") == nil)
    }
}
