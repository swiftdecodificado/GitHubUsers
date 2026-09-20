import Foundation
@testable import GitHubAPI
import Testing

struct GitHubImageTransportTests {
    private let limit = 20 * 1024 * 1024

    @Test func `oversized header is rejected before the body finishes`() async throws {
        // A small unfinished body may stay buffered by URLSession; this chunk starts the stream without an EOF.
        let server = StubServer([.init(
            status: 200,
            headers: ["Content-Length": String(limit + 1)],
            data: Data(repeating: 1, count: 64 * 1024),
            finishesLoading: false
        )])
        var request = server.request
        request.timeoutInterval = 2
        await #expect(throws: GitHubAPIError.invalidResponse) {
            try await server.session.githubImageData(for: request)
        }
        #expect(server.count == 1)
    }

    @Test(arguments: [nil, "1"] as [String?])
    func `oversized stream is rejected without trusting content length`(length: String?) async throws {
        let headers = length.map { ["Content-Length": $0] } ?? [:]
        let server = StubServer([.init(
            status: 200,
            headers: headers,
            data: Data(repeating: 1, count: limit + 1),
            finishesLoading: false
        )])
        await #expect(throws: GitHubAPIError.invalidResponse) {
            try await server.session.githubImageData(for: server.request)
        }
        #expect(server.count == 1)
    }

    @Test func `image at the exact limit is accepted`() async throws {
        let data = Data(repeating: 1, count: limit)
        let server = StubServer([.init(status: 200, data: data)])
        #expect(try await server.session.githubImageData(for: server.request) == data)
        #expect(server.count == 1)
    }

    @Test func `empty and non HTTP image responses are rejected`() async throws {
        for reply in [
            URLProtocolStub.Reply(status: 200),
            .init(status: 200, data: Data([1]), nonHTTP: true)
        ] {
            let server = StubServer([reply])
            await #expect(throws: GitHubAPIError.invalidResponse) {
                try await server.session.githubImageData(for: server.request)
            }
            #expect(server.count == 1)
        }
    }

    @Test func `retry discards the partial body`() async throws {
        let server = StubServer([
            .init(status: 200, data: Data([1, 2]), bodyError: URLError(.networkConnectionLost)),
            .init(status: 200, data: Data([3, 4]))
        ])
        #expect(try await server.session.githubImageData(for: server.request) == Data([3, 4]))
        #expect(server.count == 2)
    }

    @Test func `body transfer retries at most once`() async throws {
        let reply = URLProtocolStub.Reply(
            status: 200, data: Data([1]), bodyError: URLError(.networkConnectionLost)
        )
        let server = StubServer([reply, reply])
        await #expect(throws: GitHubAPIError.transport(.networkConnectionLost)) {
            try await server.session.githubImageData(for: server.request)
        }
        #expect(server.count == 2)
    }

    @Test func `cancelling an unfinished image transfer does not retry`() async throws {
        let server = StubServer([.init(status: 200, finishesLoading: false)])
        let task = Task { try await server.session.githubImageData(for: server.request) }
        while server.count == 0 {
            await Task.yield()
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(server.count == 1)
    }
}
