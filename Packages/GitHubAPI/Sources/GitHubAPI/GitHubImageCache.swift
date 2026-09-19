import CryptoKit
import Foundation

public actor GitHubImageCache {
    private final class MemoryEntry {
        let data: Data
        let expiry: Date

        init(data: Data, expiry: Date) {
            self.data = data
            self.expiry = expiry
        }
    }

    private struct DiskEntry {
        let size: Int
        let modified: Date
    }

    private let memory = NSCache<NSURL, MemoryEntry>()
    private var pending: [URL: Task<Data, any Error>] = [:]
    private let session: URLSession
    private let offline: Bool
    private let directory: URL
    private let maxDiskBytes: Int
    private let ttl: TimeInterval
    private let now: @Sendable () -> Date
    private var diskEntries: [String: DiskEntry] = [:]
    private var indexedDisk = false
    private var nextMaintenance = Date.distantPast

    /// Use a directory dedicated to this cache. A zero disk limit disables persistence.
    public init(
        session: URLSession = URLSession(configuration: .default),
        offline: Bool = false,
        directory: URL = URL.cachesDirectory.appending(path: "GitHubAPI/avatars"),
        maxDiskBytes: Int = 100 * 1024 * 1024,
        ttl: TimeInterval = 7 * 86400,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.session = session
        self.offline = offline
        self.directory = directory
        self.maxDiskBytes = max(0, maxDiskBytes)
        self.ttl = ttl.isFinite ? max(0, ttl) : 7 * 86400
        self.now = now
        memory.totalCostLimit = 32 * 1024 * 1024
    }

    public func data(for url: URL) async throws -> Data {
        try Task.checkCancellation()
        guard !offline else { throw GitHubAPIError.notFound }

        let date = now()
        prepareDisk(at: date)

        if let entry = memory.object(forKey: url as NSURL) {
            if entry.expiry > date {
                return entry.data
            }
            memory.removeObject(forKey: url as NSURL)
        }

        if let task = pending[url] {
            let data = try await task.value
            try Task.checkCancellation()
            return data
        }

        let filename = SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }.joined()
        let file = directory.appending(path: filename)
        if let data = cachedDiskData(at: file, for: url, date: date) {
            return data
        }

        let session = session
        // The shared transfer can finish for other readers even if one view is cancelled.
        let task = Task<Data, any Error> {
            var request = URLRequest(url: url, timeoutInterval: 15)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            return try await session.githubImageData(for: request)
        }
        pending[url] = task

        let data: Data
        do {
            data = try await task.value
        } catch {
            pending[url] = nil
            throw error
        }
        pending[url] = nil
        let fetchedAt = now()
        memory.setObject(
            MemoryEntry(data: data, expiry: fetchedAt.addingTimeInterval(ttl)),
            forKey: url as NSURL, cost: data.count
        )
        storeOnDisk(data, at: file, date: fetchedAt)
        try Task.checkCancellation()
        return data
    }

    private func cachedDiskData(at file: URL, for url: URL, date: Date) -> Data? {
        guard let entry = diskEntries[file.lastPathComponent] else { return nil }
        guard entry.modified.addingTimeInterval(ttl) > date,
              let data = try? Data(contentsOf: file) else {
            removeDiskEntry(file)
            return nil
        }
        memory.setObject(
            MemoryEntry(data: data, expiry: entry.modified.addingTimeInterval(ttl)),
            forKey: url as NSURL, cost: data.count
        )
        return data
    }

    private func prepareDisk(at date: Date) {
        if !indexedDisk {
            indexedDisk = true
            let keys: Set<URLResourceKey> = [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
                .contentModificationDateKey
            ]
            let files = (try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: Array(keys)
            )) ?? []
            for file in files {
                let name = file.lastPathComponent
                guard name.utf8.count == 64,
                      name.utf8.allSatisfy({ (48 ... 57).contains($0) || (97 ... 102).contains($0) }),
                      let values = try? file.resourceValues(forKeys: keys),
                      values.isRegularFile == true, values.isSymbolicLink != true,
                      let size = values.fileSize, let modified = values.contentModificationDate
                else { continue }
                diskEntries[name] = DiskEntry(size: size, modified: modified)
            }
        }
        guard date >= nextMaintenance else { return }
        trimDisk(at: date)
        nextMaintenance = date.addingTimeInterval(300)
    }

    private func storeOnDisk(_ data: Data, at file: URL, date: Date) {
        guard data.count <= maxDiskBytes, maxDiskBytes > 0, ttl > 0 else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            diskEntries[file.lastPathComponent] = DiskEntry(size: data.count, modified: date)
            try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.path)
        } catch {
            // Disk persistence is optional; the downloaded image remains available in memory.
        }
        trimDisk(at: date)
    }

    private func trimDisk(at date: Date) {
        for (name, entry) in diskEntries where entry.modified.addingTimeInterval(ttl) <= date {
            removeDiskEntry(directory.appending(path: name))
        }
        var total = diskEntries.values.reduce(0) { $0 + $1.size }
        // Evict the oldest writes first; reads do not change the order.
        let oldest = diskEntries.sorted {
            $0.value.modified == $1.value.modified
                ? $0.key < $1.key
                : $0.value.modified < $1.value.modified
        }
        for (name, entry) in oldest where total > maxDiskBytes {
            if removeDiskEntry(directory.appending(path: name)) {
                total -= entry.size
            }
        }
    }

    @discardableResult
    private func removeDiskEntry(_ file: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: file)
        } catch {
            guard !FileManager.default.fileExists(atPath: file.path) else { return false }
        }
        diskEntries[file.lastPathComponent] = nil
        return true
    }
}
