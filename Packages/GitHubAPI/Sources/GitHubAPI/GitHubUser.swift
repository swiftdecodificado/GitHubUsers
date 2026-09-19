//
//  GitHubUser.swift
//  GitHubAPI
//
//  Created by Luan Rodrigues on 12/09/26.
//

import Foundation

public struct GitHubUser:
    Decodable,
    Identifiable,
    Hashable,
    Sendable
{
    public let id: Int
    public let login: String
    public let name: String?
    public let avatarURL: URL
    public let htmlURL: URL

    /// As chaves correspondem ao resultado de JSONDecoder.convertFromSnakeCase.
    private enum CodingKeys: String, CodingKey {
        case id, login, name
        case avatarURL = "avatarUrl"
        case htmlURL = "htmlUrl"
    }

    public init(
        id: Int,
        login: String,
        name: String? = nil,
        avatarURL: URL,
        htmlURL: URL,
    ) {
        self.id = id
        self.login = login
        self.name = name
        self.avatarURL = avatarURL
        self.htmlURL = htmlURL
    }
}
