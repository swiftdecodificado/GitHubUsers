import Foundation
import GitHubAPI
@testable import GitHubUsers
import Testing

@MainActor struct ViewModelTests {
    @Test func `initial success is not reloaded`() async throws {
        let users = try Fixtures.users(); let mock = MockGitHubClient(pages: [.success(users)])
        let vm = UsersListViewModel(service: mock)
        await vm.onAppear(); #expect(vm.state == .loaded(users))
        await vm.onAppear()
        #expect(vm.users == users); #expect(await mock.requests.count == 1)
    }

    @Test func `empty failure retry and rate limit`() async throws {
        let empty = UsersListViewModel(service: MockGitHubClient(pages: [.success([])]))
        await empty.onAppear(); #expect(empty.state == .empty)
        let users = try Fixtures.users()
        let vm = UsersListViewModel(service: MockGitHubClient(pages: [.failure(.network), .success(users)]))
        await vm.onAppear(); #expect(vm.state == .failed(.network)); await vm.retry(); #expect(vm.state == .loaded(users))
        let reset = Date.now.addingTimeInterval(300)
        let limited = UsersListViewModel(service: MockGitHubClient(pages: [.failure(.rateLimited(resetAt: reset))]))
        await limited.onAppear(); #expect(limited.state == .failed(.rateLimited(resetAt: reset)))
        await limited.retry(); #expect(limited.state == .failed(.rateLimited(resetAt: reset)))
    }

    @Test func `pagination deduplicates and refresh resets`() async throws {
        let users = try Fixtures.users()
        let next = GitHubUser(id: 31, login: "next", avatarURL: users[0].avatarURL, htmlURL: users[0].htmlURL)
        let mock = MockGitHubClient(pages: [.success(users), .success([users[29], next]), .success([users[0]])])
        let vm = UsersListViewModel(service: mock)
        await vm.onAppear(); await vm.loadNextPageIfNeeded(currentItem: users[0])
        #expect(await mock.requests.count == 1)
        await vm.loadNextPageIfNeeded(currentItem: users[28])
        #expect(vm.users == users + [next]); #expect(await mock.requests == [.users(since: 0), .users(since: 30)])
        await vm.refresh(); #expect(vm.users == [users[0]])
        #expect(await mock.requests.last == .users(since: 0))
    }

    @Test func `concurrent pagination`() async throws {
        let users = try Fixtures.users(); let mock = MockGitHubClient(pages: [.success(users), .success([])])
        let vm = UsersListViewModel(service: mock); await vm.onAppear(); await mock.suspend()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await vm.loadNextPageIfNeeded(currentItem: users[28]) }
            while await mock.requests.count < 2 {
                await Task.yield()
            }
            group.addTask { await vm.loadNextPageIfNeeded(currentItem: users[29]) }
            await Task.yield(); await mock.resume()
        }
        #expect(await mock.requests.count == 2); #expect(!vm.isLoadingNextPage)
    }

    @Test func `search uses name and diacritics`() async throws {
        var users = try Fixtures.users()
        users[1] = GitHubUser(
            id: users[1].id,
            login: users[1].login,
            name: "MÓJO Person",
            avatarURL: users[1].avatarURL,
            htmlURL: users[1].htmlURL,
        )
        let vm = UsersListViewModel(service: MockGitHubClient(pages: [.success(users)]))
        await vm.onAppear(); vm.query = "mojo"; #expect(vm.filteredUsers.count == 2)
        vm.query = "absent"; #expect(vm.isSearchEmpty); #expect(vm.state == .loaded(users))
        vm.query = ""; #expect(vm.filteredUsers == users)
    }

    @Test func `optimistic detail and rows`() async throws {
        let user = try Fixtures.users()[0]; let detail = try Fixtures.detail()
        let vm = UserDetailViewModel(user: user, service: MockGitHubClient(details: [.success(detail)]))
        #expect(vm.login == user.login); #expect(vm.title == user.login); #expect(vm.avatarURL == user.avatarURL(size: 460))
        await vm.onAppear(); #expect(vm.state == .loaded(detail)); #expect(vm.title == detail.name)
        #expect(vm.infoRows.map(\.kind) == [.company, .location, .blog, .twitter, .memberSince]); #expect(vm.stats.count == 3)
        let sparse = GitHubUserDetail(id: user.id, login: user.login, name: nil, avatarURL: user.avatarURL, bio: nil, company: nil, location: nil, blog: "", twitterUsername: nil, publicRepos: 0, followers: 0, following: 0, createdAt: .now, htmlURL: user.htmlURL)
        let sparseVM = UserDetailViewModel(user: user, service: MockGitHubClient(details: [.success(sparse)]))
        await sparseVM.onAppear(); #expect(sparseVM.infoRows.map(\.kind) == [.memberSince]); #expect(sparseVM.bio == nil)
    }

    @Test(arguments: [(999, "pt_BR", "999"), (1000, "pt_BR", "1k"), (23100, "pt_BR", "23,1k"), (23100, "en", "23.1k")])
    func counts(value: Int, locale: String, expected: String) {
        #expect(DisplayFormatter.count(value, locale: Locale(identifier: locale)) == expected)
    }

    @Test func `cancelled detail restores state`() async throws {
        let mock = try MockGitHubClient(details: [.success(Fixtures.detail())]); await mock.suspend()
        let vm = try UserDetailViewModel(user: Fixtures.users()[0], service: mock)
        let task = Task { await vm.onAppear() }
        while await mock.requests.isEmpty {
            await Task.yield()
        }
        task.cancel(); await mock.resume(); await task.value
        #expect(vm.state == .idle)
    }
}

@MainActor struct ViewModelEdgeTests {
    @Test func `pagination failure retry and refresh failure keeps content`() async throws {
        let users = try Fixtures.users()
        let mock = MockGitHubClient(pages: [.success(users), .failure(.network), .success([]), .failure(.server)])
        let vm = UsersListViewModel(service: mock)
        await vm.onAppear(); await vm.retryPagination()
        #expect(vm.users == users); #expect(vm.paginationError == .network)
        await vm.retryPagination(); #expect(vm.paginationError == nil); #expect(!vm.hasMore)
        await vm.refresh(); #expect(vm.users == users); #expect(vm.refreshError == .server)
    }

    @Test func `refresh discards stale pagination`() async throws {
        let users = try Fixtures.users()
        let mock = MockGitHubClient(pages: [.success(users), .success(users), .success([users[0]])])
        let vm = UsersListViewModel(service: mock); await vm.onAppear(); await mock.suspend()
        let next = Task { await vm.retryPagination() }
        while await mock.requests.count < 2 {
            await Task.yield()
        }
        let refresh = Task { await vm.refresh() }
        while await mock.requests.count < 3 {
            await Task.yield()
        }
        await mock.resume(); await refresh.value; await next.value
        #expect(vm.users == [users[0]]); #expect(!vm.isLoadingNextPage)
    }

    @Test func `cancelled list restores and retries`() async throws {
        let users = try Fixtures.users()
        let mock = MockGitHubClient(pages: [.success(users), .success(users)])
        await mock.suspend()
        let vm = UsersListViewModel(service: mock)
        let task = Task { await vm.onAppear() }
        while await mock.requests.isEmpty {
            await Task.yield()
        }
        task.cancel(); await mock.resume(); await task.value
        #expect(vm.state == .idle); await vm.onAppear(); #expect(vm.users == users)
    }

    @Test func `detail error recovery`() async throws {
        let user = try Fixtures.users()[0]; let detail = try Fixtures.detail()
        let vm = UserDetailViewModel(user: user, service: MockGitHubClient(details: [.failure(.notFound), .success(detail)]))
        #expect(vm.stats.map(\.value) == ["0", "0", "0"]); #expect(vm.infoRows.isEmpty)
        await vm.onAppear(); #expect(vm.state == .failed(.notFound))
        await vm.retry(); #expect(vm.detail == detail); #expect(vm.bio == detail.bio)
        await vm.onAppear()
    }
}

@MainActor struct LifecycleTests {
    @Test func `returning from background refreshes loaded pages and preserves search`() async throws {
        let first = try Fixtures.users()
        let second = first.map { GitHubUser(id: $0.id + 30, login: "next\($0.id)", avatarURL: $0.avatarURL, htmlURL: $0.htmlURL) }
        let mock = MockGitHubClient(pages: [.success(first), .success(second), .success(first), .success(second)])
        let vm = UsersListViewModel(service: mock)
        await vm.onAppear(); await vm.retryPagination()
        vm.query = "mojo"
        await vm.refreshAfterBackground()
        #expect(vm.users == first + second)
        #expect(vm.query == "mojo")
        #expect(await mock.requests == [.users(since: 0), .users(since: 30), .users(since: 0), .users(since: 30)])
    }

    @Test func `background refresh failure keeps list`() async throws {
        let first = try Fixtures.users()
        let vm = UsersListViewModel(service: MockGitHubClient(pages: [.success(first), .failure(.network)]))
        await vm.onAppear(); await vm.refreshAfterBackground()
        #expect(vm.users == first); #expect(vm.refreshError == .network)
    }

    @Test func `detail return from background bypasses cache`() async throws {
        let detail = try Fixtures.detail()
        let mock = MockGitHubClient(details: [.success(detail), .success(detail)])
        let vm = try UserDetailViewModel(user: Fixtures.users()[0], service: mock)
        await vm.onAppear(); await vm.onAppear()
        #expect(await mock.requests.count == 1)
        await vm.refreshAfterBackground()
        #expect(vm.detail == detail)
    }
}

@MainActor struct ViewModelCacheTests {
    @Test func `list shares cache refreshes and expires`() async throws {
        let users = try Fixtures.users()
        let mock = MockGitHubClient(pages: [.success(users), .success([])])
        let cache = GitHubUserCache()
        let first = UsersListViewModel(service: mock, cache: cache)
        await first.onAppear()
        let second = UsersListViewModel(service: mock, cache: cache)
        await second.onAppear()
        #expect(second.users == users)
        #expect(await mock.requests.count == 1)
        await second.refresh()
        #expect(second.state == .empty)
        #expect(await mock.requests.count == 2)
        let expired = GitHubUserCache(ttl: -1)
        await expired.store(users, since: 0, generation: 0)
        let fresh = UsersListViewModel(service: MockGitHubClient(pages: [.success([])]), cache: expired)
        await fresh.onAppear()
        #expect(fresh.state == .empty)
    }

    @Test func `detail shares cache and background refresh replaces it`() async throws {
        let user = try Fixtures.users()[0]
        let detail = try Fixtures.detail()
        let mock = MockGitHubClient(details: [.success(detail), .success(detail), .success(detail)])
        let cache = GitHubUserCache()
        let first = UserDetailViewModel(user: user, service: mock, cache: cache)
        await first.onAppear()
        let second = UserDetailViewModel(user: user, service: mock, cache: cache)
        await second.onAppear()
        #expect(second.detail == detail)
        #expect(await mock.requests.count == 1)
        await second.refreshAfterBackground()
        #expect(await mock.requests.count == 2)
        #expect(await cache.detail(login: user.login) == detail)
        await cache.invalidate()
        let third = UserDetailViewModel(user: user, service: mock, cache: cache)
        await third.onAppear()
        #expect(await mock.requests.count == 3)
    }
}

@MainActor struct RefreshRegressionTests {
    @Test func `detail refresh failure keeps fields and retry recovers`() async throws {
        let detail = try Fixtures.detail()
        let mock = MockGitHubClient(details: [.success(detail), .failure(.network), .success(detail)])
        let vm = try UserDetailViewModel(user: Fixtures.users()[0], service: mock)
        await vm.onAppear()
        let rows = vm.infoRows
        let stats = vm.stats
        await vm.refreshAfterBackground()
        #expect(vm.state == .loaded(detail))
        #expect(vm.refreshError == .network)
        #expect(vm.infoRows == rows)
        #expect(vm.stats == stats)
        #expect(!vm.isLoadingFields)
        await vm.retry()
        #expect(vm.state == .loaded(detail))
        #expect(vm.refreshError == nil)
        #expect(await mock.requests.count == 3)
    }

    @Test func `loaded detail respects rate limit on every refresh entry point`() async throws {
        let detail = try Fixtures.detail()
        let error = GitHubAPIError.rateLimited(resetAt: .now.addingTimeInterval(300))
        let mock = MockGitHubClient(details: [.success(detail), .failure(error)])
        let vm = try UserDetailViewModel(user: Fixtures.users()[0], service: mock)
        await vm.onAppear()
        await vm.refreshAfterBackground()
        await vm.retry()
        await vm.refreshAfterBackground()
        #expect(vm.detail == detail)
        #expect(vm.refreshError == error)
        #expect(await mock.requests.count == 2)
    }

    @Test func `detail can retry after rate limit deadline`() async throws {
        let detail = try Fixtures.detail()
        let mock = MockGitHubClient(details: [.success(detail),
                                              .failure(.rateLimited(resetAt: .distantPast)), .success(detail)])
        let vm = try UserDetailViewModel(user: Fixtures.users()[0], service: mock)
        await vm.onAppear()
        await vm.refreshAfterBackground()
        await vm.retry()
        #expect(vm.refreshError == nil)
        #expect(vm.detail == detail)
        #expect(await mock.requests.count == 3)
    }

    @Test func `cancelled refresh preserves detail and previous warning`() async throws {
        let detail = try Fixtures.detail()
        let mock = MockGitHubClient(details: [.success(detail), .failure(.network), .success(detail), .success(detail)])
        let vm = try UserDetailViewModel(user: Fixtures.users()[0], service: mock)
        await vm.onAppear()
        await vm.refreshAfterBackground()
        await mock.suspend()
        let task = Task { await vm.retry() }
        while await mock.requests.count < 3 {
            await Task.yield()
        }
        // Calls while a fetch is running cannot start competing requests.
        await vm.refreshAfterBackground()
        #expect(await mock.requests.count == 3)
        task.cancel()
        await mock.resume()
        await task.value
        #expect(vm.detail == detail)
        #expect(vm.refreshError == .network)
        await vm.retry()
        #expect(vm.refreshError == nil)
        #expect(await mock.requests.count == 4)
    }

    @Test func `list refresh rate limit cannot be bypassed by gestures or pagination`() async throws {
        let users = try Fixtures.users()
        let limit = GitHubAPIError.rateLimited(resetAt: .now.addingTimeInterval(300))
        let mock = MockGitHubClient(pages: [.success(users), .failure(limit)])
        let vm = UsersListViewModel(service: mock)
        await vm.onAppear()
        await vm.refresh()
        await vm.refresh()
        await vm.refreshAfterBackground()
        await vm.retryPagination()
        #expect(await mock.requests.count == 2)
        #expect(vm.users == users)
        #expect(vm.refreshError == limit)
    }

    @Test func `pagination rate limit also blocks refresh`() async throws {
        let users = try Fixtures.users()
        let limit = GitHubAPIError.rateLimited(resetAt: .now.addingTimeInterval(300))
        let mock = MockGitHubClient(pages: [.success(users), .failure(limit)])
        let vm = UsersListViewModel(service: mock)
        await vm.onAppear()
        await vm.retryPagination()
        await vm.refresh()
        await vm.refreshAfterBackground()
        #expect(await mock.requests.count == 2)
        #expect(vm.paginationError == limit)
    }

    @Test func `search suspends pagination until cleared`() async throws {
        let users = try Fixtures.users()
        let mock = MockGitHubClient(pages: [.success(users), .success([])])
        let vm = UsersListViewModel(service: mock)
        await vm.onAppear()
        vm.query = "mojo"
        await vm.retryPagination()
        #expect(await mock.requests.count == 1)
        vm.query = ""
        await vm.retryPagination()
        #expect(await mock.requests.count == 2)
        #expect(!vm.hasMore)
    }
}
