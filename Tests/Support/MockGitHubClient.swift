import Foundation
import GitHubAPI
@testable import GitHubUsers

actor MockGitHubClient: GitHubClientProtocol {
    private var pages: [Result<[GitHubUser], GitHubAPIError>]
    private var details: [Result<GitHubUserDetail, GitHubAPIError>]
    private(set) var requests: [Endpoint] = []

    enum Endpoint: Equatable {
        case users(since: Int)
        case detail(login: String)
    }

    private var suspended = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(
        pages: [Result<[GitHubUser], GitHubAPIError>] = [],
        details: [Result<GitHubUserDetail, GitHubAPIError>] = [],
    ) {
        self.pages = pages
        self.details = details
    }

    func suspend() {
        suspended = true
    }

    func resume() {
        suspended = false
        let pending = waiters
        waiters = []
        pending.forEach { $0.resume() }
    }

    private func wait() async {
        if suspended {
            await withCheckedContinuation { waiters.append($0) }
        }
    }

    func users(since: Int, perPage _: Int) async throws -> [GitHubUser] {
        requests.append(.users(since: since))
        let result = pages.removeFirst()
        await wait()
        try Task.checkCancellation()
        return try result.get()
    }

    func detail(login: String) async throws -> GitHubUserDetail {
        requests.append(.detail(login: login))
        let result = details.removeFirst()
        await wait()
        try Task.checkCancellation()
        return try result.get()
    }
}
