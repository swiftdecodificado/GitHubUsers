import Combine
import Foundation
import GitHubAPI

struct InfoRow: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case company
        case location
        case blog
        case twitter
        case memberSince
    }

    let kind: Kind
    let value: String
    let url: URL?

    var id: Kind {
        kind
    }
}

struct UserStat: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case repositories
        case followers
        case following
    }

    let kind: Kind
    let value: String

    var id: Kind {
        kind
    }
}

@MainActor
final class UserDetailViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(GitHubUserDetail)
        case failed(GitHubAPIError)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var refreshError: GitHubAPIError?

    let user: GitHubUser

    private var isFetching = false
    private let cache: GitHubUserCache
    private let service: any GitHubClientProtocol

    init(user: GitHubUser, service: any GitHubClientProtocol, cache: GitHubUserCache = GitHubUserCache()) {
        self.user = user
        self.service = service
        self.cache = cache
    }

    var detail: GitHubUserDetail? {
        if case let .loaded(detail) = state {
            detail
        } else {
            nil
        }
    }

    var login: String {
        user.login
    }

    var title: String {
        detail?.name ?? user.name ?? login
    }

    var avatarURL: URL {
        detail?.avatarURL(size: 460) ?? user.avatarURL(size: 460)
    }

    var bio: String? {
        detail?.bio.flatMap { $0.isEmpty ? nil : $0 }
    }

    var isLoadingFields: Bool {
        state == .idle || state == .loading
    }

    var stats: [UserStat] {
        guard let detail else {
            return [
                .init(kind: .repositories, value: "0"),
                .init(kind: .followers, value: "0"),
                .init(kind: .following, value: "0"),
            ]
        }

        return [
            .init(kind: .repositories, value: DisplayFormatter.count(detail.publicRepos)),
            .init(kind: .followers, value: DisplayFormatter.count(detail.followers)),
            .init(kind: .following, value: DisplayFormatter.count(detail.following)),
        ]
    }

    var infoRows: [InfoRow] {
        guard let detail else {
            return []
        }

        var rows: [InfoRow] = []

        func append(_ kind: InfoRow.Kind, _ value: String?, url: URL? = nil) {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                return
            }

            rows.append(.init(kind: kind, value: value, url: url))
        }

        append(.company, detail.company)
        append(.location, detail.location)
        append(.blog, detail.blog, url: detail.blogURL)
        append(
            .twitter,
            detail.twitterUsername,
            url: detail.twitterUsername.flatMap { URL(string: "https://x.com/" + $0) },
        )
        append(.memberSince, detail.createdAt.formatted(.dateTime.month(.wide).year()))

        return rows
    }

    func onAppear() async {
        guard state == .idle else {
            return
        }

        await retry()
    }

    func retry() async {
        await fetch(forceRefresh: detail != nil)
    }

    func refreshAfterBackground() async {
        await fetch(forceRefresh: true)
    }

    private func fetch(forceRefresh: Bool) async {
        guard !isFetching, refreshError?.canRetry(at: .now) ?? true else {
            return
        }

        if case let .failed(error) = state, !error.canRetry(at: .now) {
            return
        }

        let previous = state
        let previousRefreshError = refreshError
        isFetching = true
        refreshError = nil

        defer { isFetching = false }

        if detail == nil {
            state = .loading
        }

        do {
            if forceRefresh {
                await cache.removeDetail(login: login)
            }
            let detail: GitHubUserDetail
            if let cached = await cache.detail(login: login) {
                detail = cached
            } else {
                let generation = await cache.generation
                detail = try await service.detail(login: login)
                try Task.checkCancellation()
                await cache.store(detail, login: login, generation: generation)
            }
            try Task.checkCancellation()
            state = .loaded(detail)
        } catch is CancellationError {
            state = previous
            refreshError = previousRefreshError
        } catch {
            if Task.isCancelled {
                state = previous
                refreshError = previousRefreshError
            } else if case .loaded = previous {
                state = previous
                refreshError = GitHubAPIError.map(error)
            } else {
                state = .failed(GitHubAPIError.map(error))
            }
        }
    }
}
