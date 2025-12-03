import Foundation

typealias TrackDownloadProgressHandler = @Sendable (Double) -> Void

final actor TrackDownloadManager {
    private struct ActiveDownload {
        let task: Task<URL, Error>
        var progressHandlers: [UUID: TrackDownloadProgressHandler]
    }

    private let cacheDirectory: URL
    private let fileManager: FileManager
    private let session: URLSession
    private let settings: SettingsStore

    private var cachedURLs: [String: URL] = [:]
    private var activeDownloads: [String: ActiveDownload] = [:]

    init(
        cacheDirectory: URL? = nil,
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        settings: SettingsStore = .shared
    ) {
        self.fileManager = fileManager
        self.session = session
        self.settings = settings

        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let directory = cachesURL.appendingPathComponent("BrainTonesMusicCache", isDirectory: true)
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            }
            self.cacheDirectory = directory
        } else {
            self.cacheDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        }

        Task {
            await loadCachedURLs()
        }
    }

    func localURL(for trackId: String) -> URL? {
        if let cached = cachedURLs[trackId], fileManager.fileExists(atPath: cached.path) {
            return cached
        }

        if let fileName = settings.cachedFileName(for: trackId) {
            let url = cacheDirectory.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: url.path) {
                cachedURLs[trackId] = url
                return url
            } else {
                awaitMain {
                    self.settings.removeCachedFileName(for: trackId)
                }
            }
        }

        return nil
    }

    func ensureDownload(for track: AudioTrack, progress: TrackDownloadProgressHandler?) -> Task<URL, Error> {
        if let local = localURL(for: track.id) {
            return Task { local }
        }

        if var active = activeDownloads[track.id] {
            if let progress {
                let token = UUID()
                active.progressHandlers[token] = progress
                Task { await notify(progress: 0, for: track.id) }
                activeDownloads[track.id] = active
            }
            return active.task
        }

        var handlers: [UUID: TrackDownloadProgressHandler] = [:]
        if let progress {
            handlers[UUID()] = progress
        }

        let task = Task { () throws -> URL in
            defer {
                Task {
                    await removeActiveDownload(for: track.id)
                }
            }
            return try await download(track: track)
        }

        activeDownloads[track.id] = ActiveDownload(task: task, progressHandlers: handlers)
        if progress != nil {
            Task { await notify(progress: 0, for: track.id) }
        }

        return task
    }

    func prefetch(track: AudioTrack) {
        _ = ensureDownload(for: track, progress: nil)
    }

    func removeCache(for trackIds: [String]) {
        for trackId in trackIds {
            if let url = cachedURLs[trackId] {
                try? fileManager.removeItem(at: url)
                cachedURLs.removeValue(forKey: trackId)
            }

            awaitMain {
                self.settings.removeCachedFileName(for: trackId)
            }
        }
    }
}

private extension TrackDownloadManager {
    func loadCachedURLs() async {
        for (trackId, fileName) in settings.cachedTrackFileNames {
            let url = cacheDirectory.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: url.path) {
                cachedURLs[trackId] = url
            } else {
                awaitMain {
                    self.settings.removeCachedFileName(for: trackId)
                }
            }
        }
    }

    func destinationURL(for track: AudioTrack) -> URL {
        let sanitizedId = track.id.replacingOccurrences(of: "/", with: "-")
        return cacheDirectory.appendingPathComponent("\(sanitizedId).mp3")
    }

    func download(track: AudioTrack) async throws -> URL {
        let destination = destinationURL(for: track)

        if fileManager.fileExists(atPath: destination.path) {
            cachedURLs[track.id] = destination
            awaitMain {
                self.settings.updateCachedFileName(destination.lastPathComponent, for: track.id)
            }
            await notify(progress: 1.0, for: track.id)
            return destination
        }

        let tempURL = cacheDirectory.appendingPathComponent(UUID().uuidString)
        fileManager.createFile(atPath: tempURL.path, contents: nil, attributes: nil)

        let handle = try FileHandle(forWritingTo: tempURL)
        defer { try? handle.close() }

        let (bytes, response) = try await session.bytes(from: track.remoteURL)
        let expectedLength = response.expectedContentLength

        var received: Int64 = 0
        var buffer = Data()
        buffer.reserveCapacity(64 * 1024)

        for try await byte in bytes {
            buffer.append(byte)
            received += 1

            if buffer.count >= 64 * 1024 {
                try handle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
            }

            if expectedLength > 0 {
                let fraction = Double(received) / Double(expectedLength)
                await notify(progress: max(0, min(1, fraction)), for: track.id)
            }
        }

        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
        }

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.moveItem(at: tempURL, to: destination)
        cachedURLs[track.id] = destination

        await notify(progress: 1.0, for: track.id)
        awaitMain {
            self.settings.updateCachedFileName(destination.lastPathComponent, for: track.id)
        }

        return destination
    }

    func notify(progress: Double, for trackId: String) async {
        guard let active = activeDownloads[trackId] else { return }
        for handler in active.progressHandlers.values {
            await MainActor.run {
                handler(progress)
            }
        }
    }

    func removeActiveDownload(for trackId: String) async {
        activeDownloads.removeValue(forKey: trackId)
    }

    func awaitMain(_ action: @escaping () -> Void) {
        Task { @MainActor in
            action()
        }
    }
}
