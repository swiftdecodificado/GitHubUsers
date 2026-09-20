import Foundation

public extension URLSession {
    func githubImageData(for request: URLRequest) async throws -> Data {
        let maximumResponseBytes = 20 * 1024 * 1024

        func send(retryOnURLError: Bool) async throws -> Data {
            do {
                try Task.checkCancellation()
                let (bytes, response) = try await self.bytes(for: request)
                // Stop the transfer if headers or the streamed body exceed the limit.
                defer { bytes.task.cancel() }

                guard let response = response as? HTTPURLResponse else {
                    throw GitHubAPIError.invalidResponse
                }

                if let error = GitHubAPIError.status(
                    response.statusCode,
                    reset: response.value(forHTTPHeaderField: "x-ratelimit-reset"),
                    retryAfter: response.value(forHTTPHeaderField: "retry-after"),
                    remaining: response.value(forHTTPHeaderField: "x-ratelimit-remaining")
                ) {
                    throw error
                }

                if let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased(),
                   !contentType.hasPrefix("image/") {
                    throw GitHubAPIError.invalidResponse
                }

                guard response.expectedContentLength <= maximumResponseBytes else {
                    throw GitHubAPIError.invalidResponse
                }

                var data = Data()
                for try await byte in bytes {
                    guard data.count < maximumResponseBytes else {
                        throw GitHubAPIError.invalidResponse
                    }
                    data.append(byte)
                }
                try Task.checkCancellation()

                guard !data.isEmpty else {
                    throw GitHubAPIError.invalidResponse
                }
                return data
            } catch {
                if error is CancellationError || Task.isCancelled || (error as? URLError)?.code == .cancelled {
                    throw CancellationError()
                }

                if retryOnURLError,
                   let code = (error as? URLError)?.code,
                   code == .timedOut || code == .networkConnectionLost {
                    try await Task.sleep(for: .milliseconds(250))
                    return try await send(retryOnURLError: false)
                }

                throw GitHubAPIError.map(error)
            }
        }

        return try await send(retryOnURLError: true)
    }
}
