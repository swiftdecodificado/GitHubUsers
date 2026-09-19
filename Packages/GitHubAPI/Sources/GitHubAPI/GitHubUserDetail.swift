//
//  GitHubUserDetail.swift
//  GitHubAPI
//
//  Created by Luan Rodrigues on 12/09/26.
//

import Foundation

public struct GitHubUserDetail: Decodable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let login: String
    public let name: String?
    public let avatarURL: URL
    public let bio: String?
    public let company: String?
    public let location: String?
    public let blog: String?
    public let twitterUsername: String?
    public let publicRepos: Int
    public let followers: Int
    public let following: Int
    public let createdAt: Date
    public let htmlURL: URL

    private enum CodingKeys: String, CodingKey {
        case id, login, name, bio, company, location, blog, twitterUsername,
             publicRepos, followers,
             following, createdAt
        case avatarURL = "avatarUrl"
        case htmlURL = "htmlUrl"
    }

    public init(
        id: Int,
        login: String,
        name: String?,
        avatarURL: URL,
        bio: String?,
        company: String?,
        location: String?,
        blog: String?,
        twitterUsername: String?,
        publicRepos: Int,
        followers: Int,
        following: Int,
        createdAt: Date,
        htmlURL: URL
    ) {
        self.id = id
        self.login = login
        self.name = name
        self.avatarURL = avatarURL
        self.bio = bio
        self.company = company
        self.location = location
        self.blog = blog
        self.twitterUsername = twitterUsername
        self.publicRepos = publicRepos
        self.followers = followers
        self.following = following
        self.createdAt = createdAt
        self.htmlURL = htmlURL
    }
}
