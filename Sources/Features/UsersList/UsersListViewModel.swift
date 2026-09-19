import Combine
import Foundation
import GitHubAPI

@MainActor
final class UsersListViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded([GitHubUser])
        case empty
        case failed(GitHubAPIError)
    }

    private enum LoadReason: Equatable {
        case firstPage
        case pullToRefresh
        case returnFromBackground

        var forceRefresh: Bool {
            switch self {
            case .firstPage:
                false
            case .pullToRefresh, .returnFromBackground:
                true
            }
        }

        var preservesLoadedPageCount: Bool {
            self == .returnFromBackground
        }

        var countsAsRefresh: Bool {
            self != .firstPage
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var paginationError: GitHubAPIError?
    @Published private(set) var refreshError: GitHubAPIError?
    @Published private(set) var refreshCompleted = 0
    @Published private(set) var hasMore = true
    @Published var query = ""
    private let cache: GitHubUserCache
    private let service: any GitHubClientProtocol
    private var cursor = 0
    private var generation = 0
    private var isRefreshing = false
    private let pageSize = 30

    var users: [GitHubUser] {
        if case let .loaded(users) = state {
            users
        } else {
            []
        }
    }

    var filteredUsers: [GitHubUser] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return users
        }

        return users.filter { user in
            [user.login, user.name ?? ""].contains {
                $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }

    var isSearchEmpty: Bool {
        !users.isEmpty && filteredUsers.isEmpty
    }

    init(service: any GitHubClientProtocol, cache: GitHubUserCache = GitHubUserCache()) {
        self.service = service
        self.cache = cache
    }

    func onAppear() async {
        guard state == .idle else {
            return
        }

        await load(.firstPage)
    }

    func refresh() async {
        await load(.pullToRefresh)
    }

    func refreshAfterBackground() async {
        await load(.returnFromBackground)
    }

    func retry() async {
        guard !isRefreshing, state != .loading else {
            return
        }

        await load(.firstPage)
    }

    private func load(_ reason: LoadReason) async {
        guard !isRefreshing,
              refreshError?.canRetry(at: .now) ?? true,
              paginationError?.canRetry(at: .now) ?? true
        else {
            return
        }

        if case let .failed(error) = state, !error.canRetry(at: .now) {
            return
        }

        isRefreshing = true
        generation += 1

        let previous = state
        let existing = users

        isLoadingNextPage = false
        paginationError = nil
        refreshError = nil

        if existing.isEmpty {
            state = .loading
        }

        defer { isRefreshing = false }

        do {
            let result = try await loadUsers(for: reason, replacing: existing)
            try Task.checkCancellation()

            cursor = result.nextCursor
            hasMore = result.lastPageCount == pageSize
            state = result.users.isEmpty ? .empty : .loaded(result.users)

            if reason.countsAsRefresh {
                refreshCompleted += 1
            }
        } catch is CancellationError {
            state = previous
        } catch {
            if Task.isCancelled {
                state = previous
                return
            }

            if existing.isEmpty {
                state = .failed(GitHubAPIError.map(error))
            } else {
                refreshError = GitHubAPIError.map(error)
            }
        }
    }

    private func loadUsers(for reason: LoadReason, replacing existing: [GitHubUser]) async throws -> (
        users: [GitHubUser],
        nextCursor: Int,
        lastPageCount: Int,
    ) {
        var page = try await cachedUsers(since: 0, forceRefresh: reason.forceRefresh)
        var combined = page
        var nextCursor = page.map(\.id).max() ?? 0

        while reason.preservesLoadedPageCount, combined.count < existing.count, page.count == pageSize {
            page = try await cachedUsers(since: nextCursor, forceRefresh: false)
            let newCursor = page.map(\.id).max() ?? nextCursor

            guard newCursor > nextCursor else {
                break
            }

            combined += page
            nextCursor = newCursor
        }

        var ids = Set<Int>()
        let unique = combined.filter { ids.insert($0.id).inserted }

        return (users: unique, nextCursor: nextCursor, lastPageCount: page.count)
    }

    private func cachedUsers(since: Int, forceRefresh: Bool) async throws -> [GitHubUser] {
        if forceRefresh {
            await cache.invalidate()
        }
        if let users = await cache.users(since: since) {
            return users
        }
        let generation = await cache.generation
        let users = try await service.users(since: since)
        try Task.checkCancellation()
        await cache.store(users, since: since, generation: generation)
        return users
    }

    func loadNextPageIfNeeded(currentItem: GitHubUser) async {
        guard !isRefreshing, !isLoadingNextPage, hasMore, query.isEmpty,
              let index = users.firstIndex(where: { $0.id == currentItem.id }), index >= users.count - 5,
              paginationError?.canRetry(at: .now) ?? true,
              refreshError?.canRetry(at: .now) ?? true
        else {
            return
        }

        isLoadingNextPage = true
        paginationError = nil

        let requestGeneration = generation
        let since = cursor

        defer {
            if generation == requestGeneration {
                isLoadingNextPage = false
            }
        }

        do {
            let page = try await cachedUsers(since: since, forceRefresh: false)
            try Task.checkCancellation()

            guard generation == requestGeneration else {
                return
            }

            var ids = Set(users.map(\.id))
            let merged = users + page.filter { ids.insert($0.id).inserted }
            let nextCursor = page.map(\.id).max() ?? since

            hasMore = page.count == pageSize && nextCursor > since
            cursor = max(cursor, nextCursor)
            state = .loaded(merged)
        } catch is CancellationError {
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else {
                return
            }

            paginationError = GitHubAPIError.map(error)
        }
    }

    func retryPagination() async {
        guard let last = users.last else {
            return
        }

        await loadNextPageIfNeeded(currentItem: last)
    }
}
