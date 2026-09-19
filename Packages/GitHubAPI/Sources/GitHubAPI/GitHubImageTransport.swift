import Foundation

public extension URLSession {
    func githubImageData(for request: URLRequest) async throws -> Data {
        let maximumResponseBytes = 20 * 1024 * 1024

        func send(retryOnURLError: Bool) async throws -> (Data, URLResponse) {
            do {
                return try await self.data(for: request)
            } catch {
                if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                    throw CancellationError()
                }

                if retryOnURLError,
                   let code = (error as? URLError)?.code,
                   code == .timedOut || code == .networkConnectionLost
                {
                    try Task.checkCancellation()
                    try await Task.sleep(for: .milliseconds(250))
                    return try await send(retryOnURLError: false)
                }

                throw GitHubAPIError.transport(
                    (error as? URLError)?.code ?? .unknown,
                )
            }
        }

        try Task.checkCancellation()
        let (data, response) = try await send(retryOnURLError: true)

        guard let response = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        if let error = GitHubAPIError.status(
            response.statusCode,
            reset: response.value(forHTTPHeaderField: "x-ratelimit-reset"),
            retryAfter: response.value(forHTTPHeaderField: "retry-after"),
            remaining: response.value(
                forHTTPHeaderField: "x-ratelimit-remaining",
            ),
        ) {
            throw error
        }

        if let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased(),
           !contentType.hasPrefix("image/")
        {
            throw GitHubAPIError.invalidResponse
        }

        if response.expectedContentLength > maximumResponseBytes
            || data.count > maximumResponseBytes
            || data.isEmpty
        {
            throw GitHubAPIError.invalidResponse
        }

        return data
    }
}
