import Foundation
import os

final class URLProtocolStub: URLProtocol {
    struct Reply: Sendable {
        let status: Int
        var headers: [String: String] = [:]
        var data = Data()
        var error: URLError?
        var nonHTTP = false
        var bodyError: URLError?
        var finishesLoading = true
    }

    private struct RegistryState {
        var replies: [String: [Reply]] = [:]
        var counts: [String: Int] = [:]
        var requests: [String: [URLRequest]] = [:]
    }

    final class Registry: Sendable {
        private let state = OSAllocatedUnfairLock(initialState: RegistryState())

        func register(_ replies: [Reply], host: String) {
            state.withLock {
                $0.replies[host] = replies
                $0.counts[host] = 0
                $0.requests[host] = []
            }
        }

        func next(_ request: URLRequest) -> Reply {
            let host = request.url!.host!
            return state.withLock {
                $0.counts[host, default: 0] += 1
                $0.requests[host, default: []].append(request)
                guard !($0.replies[host] ?? []).isEmpty else {
                    return Reply(status: 500, error: URLError(.resourceUnavailable))
                }
                return $0.replies[host]!.removeFirst()
            }
        }

        func requests(_ host: String) -> [URLRequest] {
            state.withLock { $0.requests[host, default: []] }
        }

        func count(_ host: String) -> Int {
            state.withLock { $0.counts[host, default: 0] }
        }
    }

    static let registry = Registry()

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let reply = Self.registry.next(request)

        if let error = reply.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let response: URLResponse = reply.nonHTTP ? URLResponse(
            url: request.url!, mimeType: nil, expectedContentLength: reply.data.count,
            textEncodingName: nil
        ) : HTTPURLResponse(
            url: request.url!,
            statusCode: reply.status,
            httpVersion: nil,
            headerFields: reply.headers
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.data)
        if let error = reply.bodyError {
            client?.urlProtocol(self, didFailWithError: error)
        } else if reply.finishesLoading {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

struct StubServer {
    let session: URLSession
    let request: URLRequest
    let host: String

    init(_ replies: [URLProtocolStub.Reply]) {
        let host = UUID().uuidString.lowercased() + ".test"
        URLProtocolStub.registry.register(replies, host: host)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]

        self.session = URLSession(configuration: configuration)
        self.request = URLRequest(url: URL(string: "https://" + host)!)
        self.host = host
    }

    var count: Int {
        URLProtocolStub.registry.count(host)
    }

    var requests: [URLRequest] {
        URLProtocolStub.registry.requests(host)
    }
}
