import Foundation
@testable import GitHubAPI
import Testing

struct GitHubClientTests {
    private let listJSON = Data(
        #"""
        [{
            "id": 42,
            "login": "someone",
            "avatar_url": "https://example.test/avatar",
            "html_url": "https://example.test/someone"
        }]
        """#.utf8
    )
    private let detailJSON = Data(
        #"""
        {
            "id": 42,
            "login": "someone",
            "avatar_url": "https://example.test/avatar",
            "html_url": "https://example.test/someone",
            "name": "Some One",
            "bio": null,
            "public_repos": 3,
            "followers": 4,
            "following": 5,
            "created_at": "2020-01-01T00:00:00Z"
        }
        """#.utf8
    )

    @Test func `list request and decoding`() async throws {
        let server = StubServer([.init(status: 200, data: listJSON)])
        let client = try GitHubClient(
            session: server.session,
            baseURL: #require(server.request.url),
            token: "test-token",
            timeout: 9
        )
        let users = try await client.users(since: 41, perPage: 12)
        let request = try #require(server.requests.first)
        #expect(request.url?.path == "/users")
        #expect(try URLComponents(url: #require(request.url), resolvingAgainstBaseURL: false)?.queryItems == [
            URLQueryItem(name: "since", value: "41"), URLQueryItem(name: "per_page", value: "12")
        ])
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
        #expect(request.value(forHTTPHeaderField: "X-GitHub-Api-Version") == "2022-11-28")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "GitHubAPI-Swift")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(request.timeoutInterval == 9)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(users.count == 1)
        #expect(users.first?.id == 42)
        #expect(users.first?.login == "someone")
        #expect(users.first?.name == nil)
        #expect(users.first?.avatarURL.absoluteString == "https://example.test/avatar")
        #expect(users.first?.htmlURL.absoluteString == "https://example.test/someone")
    }

    @Test func `detail uses login and decodes optional fields`() async throws {
        let server = StubServer([.init(status: 200, data: detailJSON)])
        let client = try GitHubClient(
            session: server.session,
            baseURL: #require(server.request.url?.appending(path: "api/v3/"))
        )
        let detail = try await client.detail(login: "someone")
        #expect(server.requests.first?.url?.path == "/api/v3/users/someone")
        #expect(server.requests.first?.url?.query == nil)
        #expect(server.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(detail.id == 42)
        #expect(detail.name == "Some One")
        #expect(detail.bio == nil)
        #expect(detail.company == nil)
        #expect(detail.blog == nil)
        #expect(detail.twitterUsername == nil)
        #expect(detail.publicRepos == 3)
        #expect(detail.followers == 4)
        #expect(detail.following == 5)
        #expect(detail.createdAt == Date(timeIntervalSince1970: 1_577_836_800))
    }

    @Test func `default page and validation`() async throws {
        let server = StubServer([.init(status: 200, data: Data("[]".utf8))])
        let client = try GitHubClient(session: server.session, baseURL: #require(server.request.url))
        #expect(try await client.users().isEmpty)
        #expect(server.requests.first?.url?.query == "since=0&per_page=30")
        for endpoint in [
            GitHubEndpoint.users(since: -1),
            .users(since: 0, perPage: 101),
            .users(since: 0, perPage: 0),
            .detail(login: ""),
            .detail(login: "a/b")
        ] {
            #expect(throws: GitHubAPIError.invalidInput) { try endpoint.request() }
        }
        #expect(throws: GitHubAPIError.invalidBaseURL) {
            try GitHubEndpoint.users(since: 0).request(
                baseURL: #require(URL(string: "http://example.test")),
                token: "token"
            )
        }
        #expect(throws: GitHubAPIError.invalidInput) {
            try GitHubEndpoint.users(since: 0).request(token: "bad\ntoken")
        }
        #expect(throws: GitHubAPIError.invalidInput) {
            try GitHubEndpoint.users(since: 0).request(timeout: 0)
        }
    }

    @Test(arguments: [401, 403, 404, 500])
    func `http errors do not retry`(status: Int) async throws {
        let server = StubServer([.init(status: status)])
        let client = try GitHubClient(session: server.session, baseURL: #require(server.request.url))
        let expected = try #require(GitHubAPIError.status(status))
        await #expect(throws: expected) { try await client.users() }
        #expect(server.count == 1)
    }

    @Test func `invalid response and decoding do not retry`() async throws {
        for reply in [
            URLProtocolStub.Reply(status: 200, data: Data("bad json".utf8)),
            .init(status: 200, data: listJSON, nonHTTP: true)
        ] {
            let server = StubServer([reply])
            let client = try GitHubClient(session: server.session, baseURL: #require(server.request.url))
            await #expect(throws: reply.nonHTTP ? GitHubAPIError.invalidResponse : .decoding) {
                try await client.users()
            }
            #expect(server.count == 1)
        }
    }

    @Test(arguments: [403, 429])
    func `rate limit uses reset header without retry`(status: Int) async throws {
        let reset = Date(timeIntervalSince1970: 4_102_444_800)
        let server = StubServer([.init(status: status, headers: [
            "x-ratelimit-remaining": "0", "x-ratelimit-reset": "4102444800"
        ])])
        let client = try GitHubClient(session: server.session, baseURL: #require(server.request.url))
        await #expect(throws: GitHubAPIError.rateLimited(resetAt: reset)) { try await client.users() }
        #expect(server.count == 1)
    }

    @Test func `secondary limit message is recognized`() async throws {
        let server = StubServer([.init(
            status: 403,
            headers: ["x-ratelimit-reset": "4102444800"],
            data: Data(#"{"message":"You have exceeded a secondary rate limit."}"#.utf8)
        )])
        let client = try GitHubClient(session: server.session, baseURL: #require(server.request.url))
        await #expect(throws: GitHubAPIError.rateLimited(resetAt: Date(timeIntervalSince1970: 4_102_444_800))) {
            try await client.users()
        }
        #expect(server.count == 1)
    }

    @Test func `retry deadlines and fallback`() {
        let now = Date(timeIntervalSince1970: 1000)
        #expect(GitHubAPIError.status(403, reset: "2000", now: now) == .forbidden)
        #expect(GitHubAPIError
            .status(403, retryAfter: "12", now: now) == .rateLimited(resetAt: now.addingTimeInterval(12)))
        #expect(GitHubAPIError
            .status(429, reset: "2000", retryAfter: "12", now: now) ==
            .rateLimited(resetAt: now.addingTimeInterval(12)))
        #expect(GitHubAPIError.status(429, reset: "900", now: now) == .rateLimited(resetAt: now))
        for header in [nil, "bad", "nan", "inf", "-1"] as [String?] {
            #expect(GitHubAPIError
                .status(429, reset: header, retryAfter: header, now: now) ==
                .rateLimited(resetAt: now.addingTimeInterval(60)))
        }
        #expect(GitHubAPIError
            .status(403, message: "Abuse detection mechanism", now: now) ==
            .rateLimited(resetAt: now.addingTimeInterval(60)))
    }

    @Test(arguments: [URLError.Code.timedOut, .networkConnectionLost])
    func `transient transport retries once`(code: URLError.Code) async throws {
        let server = StubServer([.init(status: 0, error: URLError(code)), .init(status: 200, data: listJSON)])
        let client = try GitHubClient(session: server.session, baseURL: #require(server.request.url))
        #expect(try await client.users().count == 1)
        #expect(server.count == 2)
        let failing = StubServer([.init(status: 0, error: URLError(code)), .init(status: 0, error: URLError(code))])
        let failingClient = try GitHubClient(session: failing.session, baseURL: #require(failing.request.url))
        await #expect(throws: GitHubAPIError.transport(code)) { try await failingClient.users() }
        #expect(failing.count == 2)
    }

    @Test(arguments: [URLError.Code.notConnectedToInternet, .badURL, .cannotFindHost])
    func `other transport errors do not retry`(code: URLError.Code) async throws {
        let server = StubServer([.init(status: 0, error: URLError(code))])
        let client = try GitHubClient(session: server.session, baseURL: #require(server.request.url))
        await #expect(throws: GitHubAPIError.transport(code)) { try await client.users() }
        #expect(server.count == 1)
    }

    @Test func `cancellation does not retry`() async throws {
        let server = StubServer([.init(status: 0, error: URLError(.cancelled))])
        let client = try GitHubClient(session: server.session, baseURL: #require(server.request.url))
        await #expect(throws: CancellationError.self) { try await client.users() }
        #expect(server.count == 1)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await client.users()
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(server.count == 1)
    }
}
