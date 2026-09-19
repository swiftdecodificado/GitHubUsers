import Foundation

public actor GitHubUserCache {
    private struct Entry<T: Sendable>: Sendable {
        let value: T
        let expiry: Date
    }

    private var pages: [Int: Entry<[GitHubUser]>] = [:]
    private var details: [String: Entry<GitHubUserDetail>] = [:]
    private let ttl: TimeInterval
    private let now: @Sendable () -> Date
    public private(set) var generation = 0

    public init(
        ttl: TimeInterval = 300,
        now: @escaping @Sendable () -> Date = { .now },
    ) {
        self.ttl = ttl
        self.now = now
    }

    public func users(since: Int) -> [GitHubUser]? {
        pages[since].flatMap { $0.expiry > now() ? $0.value : nil }
    }

    public func detail(login: String) -> GitHubUserDetail? {
        details[login].flatMap { $0.expiry > now() ? $0.value : nil }
    }

    public func store(_ users: [GitHubUser], since: Int, generation: Int) {
        guard generation == self.generation else {
            return
        }

        pages[since] = Entry(
            value: users,
            expiry: now().addingTimeInterval(ttl),
        )
    }

    public func store(
        _ detail: GitHubUserDetail,
        login: String,
        generation: Int,
    ) {
        guard generation == self.generation else {
            return
        }

        details[login] = Entry(
            value: detail,
            expiry: now().addingTimeInterval(ttl),
        )
    }

    public func removeDetail(login: String) {
        details[login] = nil
    }

    public func invalidate() {
        generation += 1
        pages.removeAll()
        details.removeAll()
    }
}
