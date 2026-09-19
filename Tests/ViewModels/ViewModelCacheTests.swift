import Foundation
import GitHubAPI
@testable import GitHubUsers
import Testing

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
