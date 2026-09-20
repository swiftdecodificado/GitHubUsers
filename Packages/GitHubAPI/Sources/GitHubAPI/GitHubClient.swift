//
//  GitHubClient.swift
//  GitHubAPI
//
//  Created by Luan Rodrigues on 12/09/26.
//

import Foundation

public struct GitHubClient: GitHubClientProtocol {
    private let session: URLSession
    private let baseURL: URL
    private let token: String?
    private let timeout: TimeInterval

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.github.com")!,
        token: String? = nil,
        timeout: TimeInterval = 15
    ) {
        self.session = session
        self.baseURL = baseURL
        self.token = token
        self.timeout = timeout
    }

    public func users(since: Int, perPage: Int) async throws -> [GitHubUser] {
        try await fetch([GitHubUser].self, endpoint: .users(since: since, perPage: perPage))
    }

    public func detail(login: String) async throws -> GitHubUserDetail {
        try await fetch(GitHubUserDetail.self, endpoint: .detail(login: login))
    }

    private func fetch<Value: Decodable & Sendable>(
        _ type: Value.Type,
        endpoint: GitHubEndpoint
    ) async throws -> Value {
        try Task.checkCancellation()

        let request = try endpoint.request(
            baseURL: baseURL,
            token: token,
            timeout: timeout
        )

        let (data, response) = try await sendWithRetry(request)

        try Task.checkCancellation()
        try validateResponse(response, data: data)

        return try decode(type, from: data)
    }

    private func sendWithRetry(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await send(request)
        } catch let error as GitHubAPIError {
            guard shouldRetry(error) else {
                throw error
            }

            try await Task.sleep(for: .milliseconds(250))
            return try await send(request)
        }
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()

        do {
            return try await session.data(for: request)
        } catch {
            if error is CancellationError
                || Task.isCancelled
                || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }

            throw GitHubAPIError.map(error)
        }
    }

    private func shouldRetry(_ error: GitHubAPIError) -> Bool {
        guard case let .transport(code) = error else {
            return false
        }

        switch code {
        case .timedOut, .networkConnectionLost:
            return true

        default:
            return false
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        let message: String? = if response.statusCode == 403 {
            (try? Self.decoder.decode(ErrorBody.self, from: data))?.message
        } else {
            nil
        }

        if let error = GitHubAPIError.status(
            response.statusCode,
            reset: response.value(forHTTPHeaderField: "x-ratelimit-reset"),
            retryAfter: response.value(forHTTPHeaderField: "retry-after"),
            remaining: response.value(forHTTPHeaderField: "x-ratelimit-remaining"),
            message: message
        ) {
            throw error
        }
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try Self.decoder.decode(type, from: data)
        } catch {
            throw GitHubAPIError.decoding
        }
    }
}

private struct ErrorBody: Decodable {
    let message: String?
}
