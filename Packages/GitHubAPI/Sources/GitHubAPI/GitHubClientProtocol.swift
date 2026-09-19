//
//  GitHubClientProtocol.swift
//  GitHubAPI
//
//  Created by Luan Rodrigues on 12/09/26.
//

/// Operações de consulta de usuários da API do GitHub.
public protocol GitHubClientProtocol: Sendable {
    func users(
        since: Int,
        perPage: Int
    ) async throws -> [GitHubUser]

    func detail(login: String) async throws -> GitHubUserDetail
}

public extension GitHubClientProtocol {
    /// Consulta até 30 usuários com IDs maiores que `since`.
    func users(
        since: Int = 0
    ) async throws -> [GitHubUser] {
        try await users(since: since, perPage: 30)
    }
}
