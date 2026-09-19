import Foundation
import GitHubAPI
@testable import GitHubUsers
import Testing

@MainActor struct ViewModelTests {
    @Test func `initial success is not reloaded`() async throws {
        let users = try Fixtures.users()
        let mock = MockGitHubClient(pages: [.success(users)])
        let viewModel = UsersListViewModel(service: mock)
        await viewModel.onAppear()
        #expect(viewModel.state == .loaded(users))
        await viewModel.onAppear()
        #expect(viewModel.users == users)
        #expect(await mock.requests.count == 1)
    }

    @Test func `empty failure retry and rate limit`() async throws {
        let empty = UsersListViewModel(service: MockGitHubClient(pages: [.success([])]))
        await empty.onAppear()
        #expect(empty.state == .empty)
        let users = try Fixtures.users()
        let viewModel = UsersListViewModel(service: MockGitHubClient(pages: [.failure(.network), .success(users)]))
        await viewModel.onAppear()
        #expect(viewModel.state == .failed(.network))
        await viewModel.retry()
        #expect(viewModel.state == .loaded(users))
        let reset = Date.now.addingTimeInterval(300)
        let limited = UsersListViewModel(service: MockGitHubClient(pages: [.failure(.rateLimited(resetAt: reset))]))
        await limited.onAppear()
        #expect(limited.state == .failed(.rateLimited(resetAt: reset)))
        await limited.retry()
        #expect(limited.state == .failed(.rateLimited(resetAt: reset)))
    }

    @Test func `pagination deduplicates and refresh resets`() async throws {
        let users = try Fixtures.users()
        let next = GitHubUser(id: 31, login: "next", avatarURL: users[0].avatarURL, htmlURL: users[0].htmlURL)
        let mock = MockGitHubClient(pages: [.success(users), .success([users[29], next]), .success([users[0]])])
        let viewModel = UsersListViewModel(service: mock)
        await viewModel.onAppear()
        await viewModel.loadNextPageIfNeeded(currentItem: users[0])
        #expect(await mock.requests.count == 1)
        await viewModel.loadNextPageIfNeeded(currentItem: users[28])
        #expect(viewModel.users == users + [next])
        #expect(await mock.requests == [.users(since: 0), .users(since: 30)])
        await viewModel.refresh()
        #expect(viewModel.users == [users[0]])
        #expect(await mock.requests.last == .users(since: 0))
    }

    @Test func `concurrent pagination`() async throws {
        let users = try Fixtures.users()
        let mock = MockGitHubClient(pages: [.success(users), .success([])])
        let viewModel = UsersListViewModel(service: mock)
        await viewModel.onAppear()
        await mock.suspend()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await viewModel.loadNextPageIfNeeded(currentItem: users[28]) }
            while await mock.requests.count < 2 {
                await Task.yield()
            }
            group.addTask { await viewModel.loadNextPageIfNeeded(currentItem: users[29]) }
            await Task.yield()
            await mock.resume()
        }
        #expect(await mock.requests.count == 2)
        #expect(!viewModel.isLoadingNextPage)
    }

    @Test func `search uses name and diacritics`() async throws {
        var users = try Fixtures.users()
        users[1] = GitHubUser(
            id: users[1].id,
            login: users[1].login,
            name: "MÓJO Person",
            avatarURL: users[1].avatarURL,
            htmlURL: users[1].htmlURL
        )
        let viewModel = UsersListViewModel(service: MockGitHubClient(pages: [.success(users)]))
        await viewModel.onAppear()
        viewModel.query = "mojo"
        #expect(viewModel.filteredUsers.count == 2)
        viewModel.query = "absent"
        #expect(viewModel.isSearchEmpty)
        #expect(viewModel.state == .loaded(users))
        viewModel.query = ""
        #expect(viewModel.filteredUsers == users)
    }

    @Test func `optimistic detail and rows`() async throws {
        let user = try Fixtures.users()[0]
        let detail = try Fixtures.detail()
        let viewModel = UserDetailViewModel(user: user, service: MockGitHubClient(details: [.success(detail)]))
        #expect(viewModel.login == user.login)
        #expect(viewModel.title == user.login)
        #expect(viewModel.avatarURL == user.avatarURL(size: 460))
        await viewModel.onAppear()
        #expect(viewModel.state == .loaded(detail))
        #expect(viewModel.title == detail.name)
        #expect(viewModel.infoRows.map(\.kind) == [.company, .location, .blog, .twitter, .memberSince])
        #expect(viewModel.stats.count == 3)
        let sparse = GitHubUserDetail(
            id: user.id,
            login: user.login,
            name: nil,
            avatarURL: user.avatarURL,
            bio: nil,
            company: nil,
            location: nil,
            blog: "",
            twitterUsername: nil,
            publicRepos: 0,
            followers: 0,
            following: 0,
            createdAt: .now,
            htmlURL: user.htmlURL
        )
        let sparseVM = UserDetailViewModel(user: user, service: MockGitHubClient(details: [.success(sparse)]))
        await sparseVM.onAppear()
        #expect(sparseVM.infoRows.map(\.kind) == [.memberSince])
        #expect(sparseVM.bio == nil)
    }

    @Test(arguments: [(999, "pt_BR", "999"), (1000, "pt_BR", "1k"), (23100, "pt_BR", "23,1k"), (23100, "en", "23.1k")])
    func counts(value: Int, locale: String, expected: String) {
        #expect(DisplayFormatter.count(value, locale: Locale(identifier: locale)) == expected)
    }

    @Test func `cancelled detail restores state`() async throws {
        let mock = try MockGitHubClient(details: [.success(Fixtures.detail())])
        await mock.suspend()
        let viewModel = try UserDetailViewModel(user: Fixtures.users()[0], service: mock)
        let task = Task { await viewModel.onAppear() }
        while await mock.requests.isEmpty {
            await Task.yield()
        }
        task.cancel()
        await mock.resume()
        await task.value
        #expect(viewModel.state == .idle)
    }
}
