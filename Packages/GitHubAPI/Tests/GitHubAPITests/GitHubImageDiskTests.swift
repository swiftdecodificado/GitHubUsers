import CryptoKit
import Foundation
@testable import GitHubAPI
import os
import Testing

private final class CacheClock: Sendable {
    private let value: OSAllocatedUnfairLock<Date>
    init(_ date: Date) {
        value = OSAllocatedUnfairLock(initialState: date)
    }

    func now() -> Date {
        value.withLock { $0 }
    }

    func advance(_ seconds: TimeInterval) {
        value.withLock { $0 += seconds }
    }
}

struct GitHubImageDiskTests {
    private func file(for url: URL, in directory: URL) -> URL {
        directory.appending(path: SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }.joined())
    }

    private func seed(_ data: Data, url: URL, directory: URL, date: Date) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = file(for: url, in: directory)
        try data.write(to: target)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: target.path)
    }

    @Test func `expired entries are removed and memory expires`() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = CacheClock(Date(timeIntervalSince1970: 1000))
        let server = StubServer([.init(status: 200, data: Data([1])), .init(status: 200, data: Data([2]))])
        let url = try #require(server.request.url)
        let expired = url.appending(path: "expired")
        try seed(Data([0]), url: expired, directory: directory, date: clock.now().addingTimeInterval(-50))
        let cache = GitHubImageCache(session: server.session, directory: directory, ttl: 50, now: clock.now)
        #expect(try await cache.data(for: url) == Data([1]))
        #expect(!FileManager.default.fileExists(atPath: file(for: expired, in: directory).path))
        clock.advance(50)
        #expect(try await cache.data(for: url) == Data([2]))
        #expect(server.count == 2)
        #expect(try Data(contentsOf: file(for: url, in: directory)) == Data([2]))
    }

    @Test func `disk limit evicts oldest write even after read`() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = CacheClock(Date(timeIntervalSince1970: 1000))
        let server = StubServer((1 ... 3).map { .init(status: 200, data: Data(repeating: UInt8($0), count: 4)) })
        let base = try #require(server.request.url)
        let urls = (1 ... 3).map { base.appending(path: String($0)) }
        let cache = GitHubImageCache(session: server.session, directory: directory, maxDiskBytes: 8, now: clock.now)
        _ = try await cache.data(for: urls[0])
        clock.advance(1)
        _ = try await cache.data(for: urls[1])
        _ = try await cache.data(for: urls[0])
        clock.advance(1)
        _ = try await cache.data(for: urls[2])
        #expect(!FileManager.default.fileExists(atPath: file(for: urls[0], in: directory).path))
        #expect(try Data(contentsOf: file(for: urls[1], in: directory)).count == 4)
        #expect(try Data(contentsOf: file(for: urls[2], in: directory)).count == 4)
        #expect(server.count == 3)
    }

    @Test func `initial maintenance trims only owned regular files`() async throws {
        let parent = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let directory = parent.appending(path: "cache")
        defer { try? FileManager.default.removeItem(at: parent) }
        let clock = CacheClock(Date(timeIntervalSince1970: 1000))
        let server = StubServer([])
        let base = try #require(server.request.url)
        let old = base.appending(path: "old")
        let recent = base.appending(path: "recent")
        try seed(Data([1, 1]), url: old, directory: directory, date: clock.now().addingTimeInterval(-2))
        try seed(Data([2, 2]), url: recent, directory: directory, date: clock.now())
        let outside = parent.appending(path: "keep")
        try Data([9]).write(to: outside)
        let unrelated = directory.appending(path: "unrelated.txt")
        try Data([8]).write(to: unrelated)
        let link = directory.appending(path: String(repeating: "a", count: 64))
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let cache = GitHubImageCache(session: server.session, directory: directory, maxDiskBytes: 2, now: clock.now)
        #expect(try await cache.data(for: recent) == Data([2, 2]))
        #expect(!FileManager.default.fileExists(atPath: file(for: old, in: directory).path))
        #expect(try Data(contentsOf: outside) == Data([9]))
        #expect(try Data(contentsOf: unrelated) == Data([8]))
        #expect(try link.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true)
        #expect(server.count == 0)
    }

    @Test func `disk write failure does not lose downloaded image and can recover`() async throws {
        let parent = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let directory = parent.appending(path: "blocked")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try Data([0]).write(to: directory)
        defer { try? FileManager.default.removeItem(at: parent) }
        let server = StubServer([.init(status: 200, data: Data([1])), .init(status: 200, data: Data([2]))])
        let url = try #require(server.request.url)
        let cache = GitHubImageCache(session: server.session, directory: directory)
        #expect(try await cache.data(for: url) == Data([1]))
        #expect(try await cache.data(for: url) == Data([1]))
        try FileManager.default.removeItem(at: directory)
        let second = url.appending(path: "second")
        #expect(try await cache.data(for: second) == Data([2]))
        #expect(try Data(contentsOf: file(for: second, in: directory)) == Data([2]))
        #expect(server.count == 2)
    }

    @Test func `missing disk file falls back to network`() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let server = StubServer([.init(status: 200, data: Data([3]))])
        let url = try #require(server.request.url)
        let other = url.appending(path: "other")
        try seed(Data([1]), url: url, directory: directory, date: .now)
        try seed(Data([2]), url: other, directory: directory, date: .now)
        let cache = GitHubImageCache(session: server.session, directory: directory)
        _ = try await cache.data(for: other) // Index both files without putting url into memory.
        try FileManager.default.removeItem(at: file(for: url, in: directory))
        #expect(try await cache.data(for: url) == Data([3]))
        #expect(server.count == 1)
    }

    @Test(arguments: [0, 1])
    func `images larger than disk budget still display`(limit: Int) async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let server = StubServer([.init(status: 200, data: Data([1, 2]))])
        let url = try #require(server.request.url)
        let cache = GitHubImageCache(session: server.session, directory: directory, maxDiskBytes: limit)
        #expect(try await cache.data(for: url) == Data([1, 2]))
        #expect(!FileManager.default.fileExists(atPath: file(for: url, in: directory).path))
    }

    @Test func `already cancelled reader does not start download`() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let server = StubServer([])
        let cache = GitHubImageCache(session: server.session, directory: directory)
        let url = try #require(server.request.url)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await cache.data(for: url)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(server.count == 0)
    }
}
