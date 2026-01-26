import Combine
import Foundation

@MainActor
final class MusicPlayerViewModel: ObservableObject {
    struct RecentDisplay: Identifiable {
        let playlist: AudioPlaylist
        let customName: String?
        var id: String { playlist.id }
        var displayTitle: String { customName ?? playlist.title }
    }

    @Published private(set) var playlists: [AudioPlaylist] = []
    @Published private(set) var recentPlaylists: [RecentDisplay] = []
    @Published private(set) var selectedPlaylist: AudioPlaylist?
    @Published private(set) var currentTrackIndex: Int = 0
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isBuffering: Bool = false
    @Published private(set) var downloadProgress: Double = 0
    @Published private(set) var playbackPosition: TimeInterval = 0
    @Published private(set) var playbackDuration: TimeInterval?
    @Published private(set) var errorMessage: String?
    @Published private(set) var downloadedTrackIds: Set<String> = []

    var currentTrack: AudioTrack? {
        guard let playlist = selectedPlaylist else { return nil }
        return playlist.tracks[safe: currentTrackIndex]
    }

    private let catalogService: MusicCatalogServicing
    private let controller: MusicPlaybackControlling
    private let settings: SettingsStore
    private let playbackCoordinator: MediaPlaybackCoordinator

    private var cancellables: Set<AnyCancellable> = []
    private var autoSaveTimer: Timer?
    private var lastKnownPlayback: MusicPlaybackState?
    private var lastKnownTrackId: String?
    private var lastIsPlaying: Bool = false

    init(
        catalogService: MusicCatalogServicing = MusicCatalogService(),
        controller: MusicPlaybackControlling? = nil,
        settings: SettingsStore = .shared,
        playbackCoordinator: MediaPlaybackCoordinator? = nil,
        autoRestore: Bool = true
    ) {
        self.catalogService = catalogService
        self.controller = controller ?? MusicPlaybackController()
        self.settings = settings
        self.playbackCoordinator = playbackCoordinator ?? MediaPlaybackCoordinator.shared

        observeController()
        observeRecents()
        observeDownloads()
        registerWithCoordinator()

        Task {
            await loadCatalog(autoRestore: autoRestore)
        }
    }

    deinit {
        autoSaveTimer?.invalidate()
    }

    // MARK: - Public API

    func togglePlayback() {
        controller.togglePlayback()
    }

    func play() {
        controller.play()
    }

    func pause() {
        controller.pause()
    }

    func skipForward() {
        controller.skipForward()
    }

    func skipBackward() {
        controller.skipBackward()
    }

    func seek(to time: TimeInterval) {
        controller.seek(to: time)
        playbackPosition = time
        persistLatestPlayback()
    }

    func selectPlaylist(_ playlist: AudioPlaylist, autoplay: Bool = false) {
        guard playlist.id != selectedPlaylist?.id else { return }
        persistLatestPlayback()
        selectedPlaylist = playlist
        settings.currentPlaylistId = playlist.id

        let savedState = settings.playbackState(for: playlist.id)
        let startIndex = savedState?.trackIndex ?? playlist.defaultStartIndex
        let startTime = savedState?.playbackTime ?? 0

        controller.configure(
            with: playlist,
            startIndex: startIndex,
            startTime: startTime,
            autoplay: autoplay
        )

        currentTrackIndex = startIndex
        downloadProgress = 0
        playbackPosition = startTime
        playbackDuration = nil
    }

    func selectTrack(at index: Int, autoplay: Bool = true) {
        guard let playlist = selectedPlaylist else { return }
        guard playlist.tracks.indices.contains(index) else { return }

        // Tapping the currently selected track should not restart it.
        if index == currentTrackIndex {
            if autoplay, !isPlaying {
                controller.play()
            }
            return
        }

        persistLatestPlayback()
        currentTrackIndex = index

        let track = playlist.tracks[index]
        let startTime = settings.playbackPosition(for: track.id) ?? 0
        controller.selectTrack(at: index, startTime: startTime, autoplay: autoplay)
    }

    func addSelectedPlaylistToRecents(customName: String?) {
        guard let playlist = selectedPlaylist else { return }
        let trimmed = customName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (trimmed?.isEmpty ?? true) ? nil : trimmed
        settings.updateRecentPlaylist(id: playlist.id, customName: name)
    }

    func removeRecentPlaylist(_ id: String) {
        settings.removeRecentPlaylist(withId: id)
    }

    func loadRecentPlaylist(_ id: String) {
        guard let playlist = playlists.first(where: { $0.id == id }) else { return }
        selectPlaylist(playlist, autoplay: false)
    }

    // MARK: - Setup

    private func observeController() {
        controller.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleStateUpdate(state)
            }
            .store(in: &cancellables)
    }

    private func observeRecents() {
        recentPlaylists = buildRecentDisplays(from: settings.recentPlaylists)

        settings.$recentPlaylists
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.recentPlaylists = self?.buildRecentDisplays(from: entries) ?? []
            }
            .store(in: &cancellables)
    }

    private func observeDownloads() {
        downloadedTrackIds = Set(settings.cachedTrackFileNames.keys)

        settings.$cachedTrackFileNames
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.downloadedTrackIds = Set(entries.keys)
            }
            .store(in: &cancellables)
    }

    private func registerWithCoordinator() {
        playbackCoordinator.registerMusicControls(
            play: { [weak self] in Task { @MainActor in self?.controller.play() } },
            pause: { [weak self] in Task { @MainActor in self?.controller.pause() } },
            skipForward: { [weak self] in Task { @MainActor in self?.controller.skipForward() } },
            skipBackward: { [weak self] in Task { @MainActor in self?.controller.skipBackward() } },
            seek: { [weak self] time in Task { @MainActor in self?.controller.seek(to: time) } }
        )
    }

    private func loadCatalog(autoRestore: Bool) async {
        do {
            let playlists = try catalogService.loadCatalog()
            await MainActor.run {
                self.playlists = playlists
                self.recentPlaylists = self.buildRecentDisplays(from: self.settings.recentPlaylists)

                if autoRestore, let playlistId = self.settings.currentPlaylistId,
                   let playlist = playlists.first(where: { $0.id == playlistId }) {
                    self.selectPlaylist(playlist, autoplay: false)
                } else if let first = playlists.first {
                    self.selectPlaylist(first, autoplay: false)
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load catalog: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - State Handling

    private func handleStateUpdate(_ state: MusicPlayerRuntimeState) {
        if let playlist = state.playlist {
            selectedPlaylist = playlist
            currentTrackIndex = state.trackIndex
            settings.currentPlaylistId = playlist.id
            lastKnownPlayback = MusicPlaybackState(
                playlistId: playlist.id,
                trackIndex: state.trackIndex,
                playbackTime: state.position
            )
            lastKnownTrackId = state.track?.id
        }

        isPlaying = state.isPlaying
        isBuffering = state.isBuffering
        downloadProgress = state.downloadProgress
        playbackPosition = state.position
        playbackDuration = state.duration

        if state.isPlaying != lastIsPlaying {
            lastIsPlaying = state.isPlaying
            if state.isPlaying {
                startAutoSaveTimer()
            } else {
                stopAutoSaveTimer()
                persistLatestPlayback()
            }
        }
    }

    // MARK: - Persistence

    private func startAutoSaveTimer() {
        guard autoSaveTimer == nil else { return }
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 29, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.persistLatestPlayback()
            }
        }
    }

    private func stopAutoSaveTimer() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    private func persistLatestPlayback() {
        guard let playback = lastKnownPlayback else { return }
        settings.updatePlaybackState(playback)
        if let trackId = lastKnownTrackId {
            settings.updatePlaybackPosition(playback.playbackTime, for: trackId)
        }
    }

    // MARK: - Helpers

    private func buildRecentDisplays(from entries: [MusicRecentPlaylist]) -> [RecentDisplay] {
        playlists.compactMap { playlist in
            guard let entry = entries.first(where: { $0.playlistId == playlist.id }) else { return nil }
            return RecentDisplay(playlist: playlist, customName: entry.customName)
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
