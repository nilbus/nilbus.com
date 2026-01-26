import Foundation

typealias TrackDownloadProgressHandler = @Sendable (Double) -> Void
typealias TrackDownloadProgressToken = UUID

final actor TrackDownloadManager {
    private struct ActiveDownload {
        let task: Task<URL, Error>
        var progressHandlers: [TrackDownloadProgressToken: TrackDownloadProgressHandler]
        var latestProgress: Double
    }

    private let downloadsDirectory: URL
    private let legacyCacheDirectory: URL?
    private let fileManager: FileManager
    private let session: URLSession
    private let settings: SettingsStore

    private var cachedURLs: [String: URL] = [:]
    private var activeDownloads: [String: ActiveDownload] = [:]

    init(
        downloadsDirectory: URL? = nil,
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        settings: SettingsStore = .shared
    ) {
        self.fileManager = fileManager
        self.session = session
        self.settings = settings

        let legacyDirectory: URL? = fileManager
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("BrainTonesMusicCache", isDirectory: true)
        self.legacyCacheDirectory = legacyDirectory

        if let downloadsDirectory {
            self.downloadsDirectory = downloadsDirectory
        } else if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let directory = appSupportURL.appendingPathComponent("BrainTonesMusicDownloads", isDirectory: true)
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            }
            try? Self.excludeFromBackup(directory)
            self.downloadsDirectory = directory
        } else if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let directory = cachesURL.appendingPathComponent("BrainTonesMusicDownloads", isDirectory: true)
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            }
            try? Self.excludeFromBackup(directory)
            self.downloadsDirectory = directory
        } else {
            self.downloadsDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        }

        Task {
            await loadCachedURLs()
        }
    }

    func localURL(for trackId: String) -> URL? {
        if let cached = cachedURLs[trackId], fileManager.fileExists(atPath: cached.path) {
            return cached
        }

        let expectedFileName = fileName(for: trackId)
        let settingsFileName = settings.cachedFileName(for: trackId)
        let fileName = settingsFileName ?? expectedFileName

        let destination = downloadsDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: destination.path) {
            cachedURLs[trackId] = destination
            if settingsFileName != fileName {
                awaitMain {
                    self.settings.updateCachedFileName(fileName, for: trackId)
                }
            }
            return destination
        }

        if let legacy = legacyCacheDirectory {
            let legacyURL = legacy.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: legacyURL.path) {
                do {
                    if fileManager.fileExists(atPath: destination.path) {
                        try fileManager.removeItem(at: destination)
                    }
                    try fileManager.moveItem(at: legacyURL, to: destination)
                    try? Self.excludeFromBackup(destination)
                    cachedURLs[trackId] = destination
                    awaitMain {
                        self.settings.updateCachedFileName(fileName, for: trackId)
                    }
                    return destination
                } catch {
                    // If migration fails, still use legacy so playback works.
                    cachedURLs[trackId] = legacyURL
                    return legacyURL
                }
            }

            if fileName != expectedFileName {
                let legacyExpected = legacy.appendingPathComponent(expectedFileName)
                if fileManager.fileExists(atPath: legacyExpected.path) {
                    do {
                        if fileManager.fileExists(atPath: destination.path) {
                            try fileManager.removeItem(at: destination)
                        }
                        try fileManager.moveItem(at: legacyExpected, to: destination)
                        try? Self.excludeFromBackup(destination)
                        cachedURLs[trackId] = destination
                        awaitMain {
                            self.settings.updateCachedFileName(expectedFileName, for: trackId)
                        }
                        return destination
                    } catch {
                        cachedURLs[trackId] = legacyExpected
                        return legacyExpected
                    }
                }
            }
        }

        if settingsFileName != nil {
            awaitMain {
                self.settings.removeCachedFileName(for: trackId)
            }
        }

        return nil
    }

    func ensureDownload(
        for track: AudioTrack,
        progress: TrackDownloadProgressHandler?
    ) -> (task: Task<URL, Error>, token: TrackDownloadProgressToken?) {
        if let local = localURL(for: track.id) {
            return (Task { local }, nil)
        }

        if var active = activeDownloads[track.id] {
            if let progress {
                let token = TrackDownloadProgressToken()
                active.progressHandlers[token] = progress
                let latest = active.latestProgress
                activeDownloads[track.id] = active
                Task { @MainActor in
                    progress(latest)
                }
                return (active.task, token)
            }
            return (active.task, nil)
        }

        var handlers: [TrackDownloadProgressToken: TrackDownloadProgressHandler] = [:]
        let token: TrackDownloadProgressToken? = progress.map { _ in TrackDownloadProgressToken() }
        if let progress {
            handlers[token!] = progress
        }

        let task = Task { () throws -> URL in
            defer {
                Task {
                    await removeActiveDownload(for: track.id)
                }
            }
            return try await download(track: track)
        }

        activeDownloads[track.id] = ActiveDownload(task: task, progressHandlers: handlers, latestProgress: 0)
        if let progress {
            Task { @MainActor in
                progress(0)
            }
        }

        return (task, token)
    }

    func prefetch(track: AudioTrack) {
        _ = ensureDownload(for: track, progress: nil)
    }

    func removeProgressHandler(for trackId: String, token: TrackDownloadProgressToken) {
        guard var active = activeDownloads[trackId] else { return }
        active.progressHandlers.removeValue(forKey: token)
        activeDownloads[trackId] = active
    }

    func removeCache(for trackIds: [String]) {
        for trackId in trackIds {
            if let url = cachedURLs[trackId] {
                try? fileManager.removeItem(at: url)
                cachedURLs.removeValue(forKey: trackId)
            }

            let fileName = settings.cachedFileName(for: trackId) ?? fileName(for: trackId)
            let destination = downloadsDirectory.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: destination.path) {
                try? fileManager.removeItem(at: destination)
            }

            if let legacy = legacyCacheDirectory {
                let legacyURL = legacy.appendingPathComponent(fileName)
                if fileManager.fileExists(atPath: legacyURL.path) {
                    try? fileManager.removeItem(at: legacyURL)
                }
            }

            awaitMain {
                self.settings.removeCachedFileName(for: trackId)
            }
        }
    }
}

private extension TrackDownloadManager {
    func loadCachedURLs() async {
        // Populate cache with any known downloads. If the legacy cache directory contains files,
        // they will be migrated when accessed via `localURL(for:)`.
        for (trackId, fileName) in settings.cachedTrackFileNames {
            _ = localURL(for: trackId) ?? {
                let url = downloadsDirectory.appendingPathComponent(fileName)
                return fileManager.fileExists(atPath: url.path) ? url : nil
            }()
        }
    }

    func fileName(for trackId: String) -> String {
        let sanitizedId = trackId.replacingOccurrences(of: "/", with: "-")
        return "\(sanitizedId).mp3"
    }

    func destinationURL(for track: AudioTrack) -> URL {
        downloadsDirectory.appendingPathComponent(fileName(for: track.id))
    }

    func download(track: AudioTrack) async throws -> URL {
        let destination = destinationURL(for: track)

        if fileManager.fileExists(atPath: destination.path) {
            cachedURLs[track.id] = destination
            awaitMain {
                self.settings.updateCachedFileName(destination.lastPathComponent, for: track.id)
            }
            await sendProgress(1.0, for: track.id, force: true)
            return destination
        }

        let tempURL = downloadsDirectory.appendingPathComponent(UUID().uuidString)
        fileManager.createFile(atPath: tempURL.path, contents: nil, attributes: nil)

        let handle = try FileHandle(forWritingTo: tempURL)
        defer { try? handle.close() }

        let (bytes, response) = try await session.bytes(from: track.remoteURL)
        let expectedLength = response.expectedContentLength

        var received: Int64 = 0
        var buffer = Data()
        buffer.reserveCapacity(256 * 1024)
        var lastReportedProgress: Double = 0

        for try await byte in bytes {
            buffer.append(byte)
            received += 1

            if buffer.count >= 256 * 1024 {
                try handle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)

                if expectedLength > 0 {
                    let fraction = Double(received) / Double(expectedLength)
                    let clamped = max(0, min(1, fraction))
                    if clamped - lastReportedProgress >= 0.005 {
                        lastReportedProgress = clamped
                        await sendProgress(clamped, for: track.id)
                    }
                }
            }
        }

        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
        }

        if expectedLength > 0 {
            let fraction = Double(received) / Double(expectedLength)
            let clamped = max(0, min(1, fraction))
            await sendProgress(clamped, for: track.id)
        }

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.moveItem(at: tempURL, to: destination)
        try? Self.excludeFromBackup(destination)
        cachedURLs[track.id] = destination

        await sendProgress(1.0, for: track.id, force: true)
        awaitMain {
            self.settings.updateCachedFileName(destination.lastPathComponent, for: track.id)
        }

        return destination
    }

    func sendProgress(_ progress: Double, for trackId: String, force: Bool = false) async {
        guard var active = activeDownloads[trackId] else { return }

        let clamped = max(0, min(1, progress))
        let monotonic = max(active.latestProgress, clamped)
        if !force, monotonic <= active.latestProgress { return }

        active.latestProgress = monotonic
        activeDownloads[trackId] = active

        for handler in active.progressHandlers.values {
            await MainActor.run {
                handler(monotonic)
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

    static func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }
}
