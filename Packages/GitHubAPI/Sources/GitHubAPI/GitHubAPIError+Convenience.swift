import Foundation

public extension GitHubAPIError {
    static var network: GitHubAPIError {
        .transport(.notConnectedToInternet)
    }

    static var server: GitHubAPIError {
        .http(statusCode: 500)
    }

    var resetAt: Date? {
        if case let .rateLimited(date) = self {
            date
        } else {
            nil
        }
    }

    func canRetry(at date: Date) -> Bool {
        resetAt.map { date >= $0 } ?? true
    }

    func remaining(at date: Date) -> String {
        guard let resetAt else {
            return ""
        }

        let seconds = max(0, Int(ceil(resetAt.timeIntervalSince(date))))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    static func map(_ error: any Error) -> GitHubAPIError {
        if let error = error as? GitHubAPIError {
            return error
        }

        if error is DecodingError {
            return .decoding
        }

        if let error = error as? URLError {
            return .transport(error.code)
        }

        return .unknown
    }
}
