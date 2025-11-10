import Foundation
import Combine

@MainActor
final class YouTubeViewModel: ObservableObject {
    @Published var playlistURL: String
    @Published var currentPlaylist: YouTubePlaylist?
    @Published var recentPlaylists: [RecentPlaylist] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var activePlaylistId: String?
    @Published var startIndex: Int = 0
    @Published var startTime: Double = 0
    @Published var isPlayerReady = false
    @Published var isPlayerPlaying = false

    private let service: YouTubeServicing
    private let settings: SettingsStore
    private var cancellables: Set<AnyCancellable> = []
    private var autoSaveTimer: Timer?
    private var lastKnownPlayback: PlaylistPlaybackState?

    init(
        service: YouTubeServicing = YouTubeService(apiKey: YouTubeConfig.apiKey),
        settings: SettingsStore = .shared,
        autoRestore: Bool = true
    ) {
        self.service = service
        self.settings = settings
        playlistURL = settings.currentPlaylistURL?.absoluteString ?? ""
        activePlaylistId = settings.currentPlaylistId

        settings.$recentPlaylists
            .receive(on: DispatchQueue.main)
            .assign(to: \.recentPlaylists, on: self)
            .store(in: &cancellables)

        if autoRestore {
            Task { [weak self] in
                await self?.restoreExistingPlaylist()
            }
        }
    }

    deinit {
        autoSaveTimer?.invalidate()
    }

    func restoreExistingPlaylist() async {
        guard let playlistId = activePlaylistId else { return }
        do {
            isLoading = true
            let playlist = try await service.fetchPlaylist(id: playlistId)
            applyLoadedPlaylist(playlist, shouldAutoplay: false)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadPlaylistFromCurrentURL() async {
        errorMessage = nil
        guard let playlistId = extractPlaylistId(from: playlistURL) else {
            errorMessage = YouTubeError.invalidPlaylistId.errorDescription
            return
        }
        await loadPlaylist(withId: playlistId, urlString: playlistURL)
    }

    func loadRecentPlaylist(_ playlist: RecentPlaylist) async {
        playlistURL = playlist.url.absoluteString
        await loadPlaylist(withId: playlist.id, urlString: playlist.url.absoluteString)
    }

    func deleteRecentPlaylist(_ playlist: RecentPlaylist) {
        settings.removeRecentPlaylist(withId: playlist.id)
    }

    func playerReady() {
        isPlayerReady = true
    }

    func playerStateChanged(_ state: YouTubePlayerState, index: Int, time: Double) {
        switch state {
        case .playing:
            isPlayerPlaying = true
            startAutoSaveTimer()
        case .paused, .buffering:
            isPlayerPlaying = false
            stopAutoSaveTimer()
            persistPlaybackState(index: index, time: time)
        case .ended:
            isPlayerPlaying = false
            stopAutoSaveTimer()
            clearPlaybackState()
        default:
            break
        }
    }

    func playerProgress(index: Int, time: Double, duration: Double) {
        guard let playlistId = activePlaylistId else { return }
        lastKnownPlayback = PlaylistPlaybackState(playlistId: playlistId, videoIndex: index, playbackTime: time)
    }

    func addCurrentPlaylistToRecents(named title: String) {
        guard let playlist = currentPlaylist,
              let url = URL(string: playlistURL) else { return }

        let entry = RecentPlaylist(id: playlist.id, title: title, url: url)
        settings.addRecentPlaylist(entry)
    }
}

private extension YouTubeViewModel {
    func loadPlaylist(withId playlistId: String, urlString: String) async {
        guard !playlistId.isEmpty else {
            errorMessage = YouTubeError.invalidPlaylistId.errorDescription
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let playlist = try await service.fetchPlaylist(id: playlistId)
            applyLoadedPlaylist(playlist, shouldAutoplay: true)

            settings.currentPlaylistId = playlistId
            settings.currentPlaylistURL = URL(string: urlString)

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyLoadedPlaylist(_ playlist: YouTubePlaylist, shouldAutoplay: Bool) {
        stopAutoSaveTimer()
        persistLatestPlayback()
        currentPlaylist = playlist
        activePlaylistId = playlist.id
        isPlayerPlaying = shouldAutoplay
        errorMessage = nil

        if let savedState = settings.playlistState(for: playlist.id) {
            startIndex = savedState.videoIndex
            startTime = savedState.playbackTime
            lastKnownPlayback = savedState
        } else {
            startIndex = 0
            startTime = 0
            lastKnownPlayback = PlaylistPlaybackState(playlistId: playlist.id, videoIndex: 0, playbackTime: 0)
        }
    }

    func startAutoSaveTimer() {
        guard autoSaveTimer == nil else { return }
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 29.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.persistLatestPlayback()
            }
        }
    }

    func stopAutoSaveTimer() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    func persistLatestPlayback() {
        guard let state = lastKnownPlayback else { return }
        settings.updatePlaylistState(state)
    }

    func persistPlaybackState(index: Int, time: Double) {
        guard let playlistId = activePlaylistId else { return }
        let state = PlaylistPlaybackState(playlistId: playlistId, videoIndex: index, playbackTime: time)
        lastKnownPlayback = state
        settings.updatePlaylistState(state)
    }

    func clearPlaybackState() {
        guard let playlistId = activePlaylistId else { return }
        settings.removePlaylistState(for: playlistId)
        lastKnownPlayback = nil
    }
}
