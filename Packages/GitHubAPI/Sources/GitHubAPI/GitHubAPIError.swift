//
//  GitHubAPIError.swift
//  GitHubAPI
//
//  Created by Luan Rodrigues on 12/09/26.
//

import Foundation

public enum GitHubAPIError: Error, Sendable, Equatable {
    case invalidInput
    case invalidBaseURL
    case transport(URLError.Code)
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case http(statusCode: Int)
    case decoding
    case rateLimited(resetAt: Date)
    case unknown
}

extension GitHubAPIError {
    public static func status(
        _ code: Int,
        reset: String? = nil,
        retryAfter: String? = nil,
        remaining: String? = nil,
        message: String? = nil,
        now: Date = .now
    ) -> GitHubAPIError? {
        switch code {
        case 200 ... 299:
            return nil

        case 401:
            return .unauthorized

        case 403:
            guard
                indicatesRateLimit(
                    remaining: remaining,
                    retryAfter: retryAfter,
                    message: message
                )
            else {
                return .forbidden
            }

            return .rateLimited(
                resetAt: rateLimitResetDate(
                    resetHeader: reset,
                    retryAfter: retryAfter,
                    now: now
                )
            )

        case 404:
            return .notFound

        case 429:
            return .rateLimited(
                resetAt: rateLimitResetDate(
                    resetHeader: reset,
                    retryAfter: retryAfter,
                    now: now
                )
            )

        default:
            return .http(statusCode: code)
        }
    }

    private static func indicatesRateLimit(
        remaining: String?,
        retryAfter: String?,
        message: String?
    ) -> Bool {
        if remaining == "0" || retryAfter != nil {
            return true
        }

        guard let message else {
            return false
        }

        return message.localizedCaseInsensitiveContains("rate limit")
            || message.localizedCaseInsensitiveContains("abuse detection")
    }

    private static func rateLimitResetDate(
        resetHeader: String?,
        retryAfter: String?,
        now: Date
    ) -> Date {
        if let delay = nonNegativeFiniteNumber(retryAfter),
           delay <= Date.distantFuture.timeIntervalSince(now) {
            return now.addingTimeInterval(delay)
        }

        if let timestamp = nonNegativeFiniteNumber(resetHeader),
           timestamp <= Date.distantFuture.timeIntervalSince1970 {
            let resetDate = Date(timeIntervalSince1970: timestamp)
            return max(now, resetDate)
        }

        let fallbackDelay: TimeInterval = 60
        return now.addingTimeInterval(fallbackDelay)
    }

    private static func nonNegativeFiniteNumber(
        _ value: String?
    ) -> Double? {
        guard let value,
              let number = Double(value),
              number.isFinite,
              number >= 0
        else {
            return nil
        }

        return number
    }
}
