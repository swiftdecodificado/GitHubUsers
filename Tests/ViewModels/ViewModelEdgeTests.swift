import Foundation
import GitHubAPI
@testable import GitHubUsers
import Testing

@MainActor struct ViewModelEdgeTests {
    @Test func `pagination failure retry and refresh failure keeps content`() async throws {
        let users = try Fixtures.users()
        let mock = MockGitHubClient(pages: [.success(users), .failure(.network), .success([]), .failure(.server)])
        let viewModel = UsersListViewModel(service: mock)
        await viewModel.onAppear()
        await viewModel.retryPagination()
        #expect(viewModel.users == users)
        #expect(viewModel.paginationError == .network)
        await viewModel.retryPagination()
        #expect(viewModel.paginationError == nil)
        #expect(!viewModel.hasMore)
        await viewModel.refresh()
        #expect(viewModel.users == users)
        #expect(viewModel.refreshError == .server)
    }

    @Test func `refresh discards stale pagination`() async throws {
        let users = try Fixtures.users()
        let mock = MockGitHubClient(pages: [.success(users), .success(users), .success([users[0]])])
        let viewModel = UsersListViewModel(service: mock)
        await viewModel.onAppear()
        await mock.suspend()
        let next = Task { await viewModel.retryPagination() }
        while await mock.requests.count < 2 {
            await Task.yield()
        }
        let refresh = Task { await viewModel.refresh() }
        while await mock.requests.count < 3 {
            await Task.yield()
        }
        await mock.resume()
        await refresh.value
        await next.value
        #expect(viewModel.users == [users[0]])
        #expect(!viewModel.isLoadingNextPage)
    }

    @Test func `cancelled list restores and retries`() async throws {
        let users = try Fixtures.users()
        let mock = MockGitHubClient(pages: [.success(users), .success(users)])
        await mock.suspend()
        let viewModel = UsersListViewModel(service: mock)
        let task = Task { await viewModel.onAppear() }
        while await mock.requests.isEmpty {
            await Task.yield()
        }
        task.cancel()
        await mock.resume()
        await task.value
        #expect(viewModel.state == .idle)
        await viewModel.onAppear()
        #expect(viewModel.users == users)
    }

    @Test func `detail error recovery`() async throws {
        let user = try Fixtures.users()[0]
        let detail = try Fixtures.detail()
        let viewModel = UserDetailViewModel(
            user: user,
            service: MockGitHubClient(details: [.failure(.notFound), .success(detail)])
        )
        #expect(viewModel.stats.map(\.value) == ["0", "0", "0"])
        #expect(viewModel.infoRows.isEmpty)
        await viewModel.onAppear()
        #expect(viewModel.state == .failed(.notFound))
        await viewModel.retry()
        #expect(viewModel.detail == detail)
        #expect(viewModel.bio == detail.bio)
        await viewModel.onAppear()
    }
}
