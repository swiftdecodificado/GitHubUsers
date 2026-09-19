//
//  GitHubEndpoint.swift
//  GitHubAPI
//
//  Created by Luan Rodrigues on 12/09/26.
//

import Foundation

enum GitHubEndpoint: Equatable, Sendable {
    case users(since: Int, perPage: Int = 30)
    case detail(login: String)

    func request(
        baseURL: URL = URL(string: "https://api.github.com")!,
        token: String? = nil,
        timeout: TimeInterval = 15
    ) throws -> URLRequest {
        var components = try validatedComponents(
            baseURL: baseURL,
            requiresHTTPS: token != nil
        )

        try validateConfiguration(token: token, timeout: timeout)
        try configureURL(&components)

        guard let url = components.url else {
            throw GitHubAPIError.invalidBaseURL
        }

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeout
        )

        request.httpMethod = "GET"
        request.setValue(
            "application/vnd.github+json",
            forHTTPHeaderField: "Accept"
        )
        request.setValue(
            "2022-11-28",
            forHTTPHeaderField: "X-GitHub-Api-Version"
        )
        request.setValue(
            "GitHubAPI-Swift",
            forHTTPHeaderField: "User-Agent"
        )

        if let token {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        return request
    }

    private func validatedComponents(
        baseURL: URL,
        requiresHTTPS: Bool
    ) throws -> URLComponents {
        guard
            let components = URLComponents(
                url: baseURL,
                resolvingAgainstBaseURL: false
            ),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = components.host,
            !host.isEmpty,
            components.user == nil,
            components.password == nil,
            components.query == nil,
            components.fragment == nil,
            !requiresHTTPS || scheme == "https"
        else {
            throw GitHubAPIError.invalidBaseURL
        }

        return components
    }

    private func validateConfiguration(
        token: String?,
        timeout: TimeInterval
    ) throws {
        guard timeout.isFinite, timeout > 0 else {
            throw GitHubAPIError.invalidInput
        }

        guard let token else {
            return
        }

        let containsOnlyVisibleASCII = token.utf8.allSatisfy {
            (33 ... 126).contains($0)
        }

        guard !token.isEmpty, containsOnlyVisibleASCII else {
            throw GitHubAPIError.invalidInput
        }
    }

    private func configureURL(
        _ components: inout URLComponents
    ) throws {
        var path = components.percentEncodedPath

        while path.hasSuffix("/") {
            path.removeLast()
        }

        path += "/users"

        switch self {
        case let .users(since, perPage):
            guard since >= 0, (1 ... 100).contains(perPage) else {
                throw GitHubAPIError.invalidInput
            }

            components.queryItems = [
                URLQueryItem(name: "since", value: String(since)),
                URLQueryItem(name: "per_page", value: String(perPage))
            ]

        case let .detail(login):
            try validateLogin(login)
            path += "/\(login)"
        }

        components.percentEncodedPath = path
    }

    private func validateLogin(_ login: String) throws {
        let allowedCharacters = CharacterSet(
            charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
        )

        guard
            !login.isEmpty,
            login.unicodeScalars.allSatisfy(allowedCharacters.contains)
        else {
            throw GitHubAPIError.invalidInput
        }
    }
}
