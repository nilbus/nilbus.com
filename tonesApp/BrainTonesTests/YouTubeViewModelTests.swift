import XCTest
@testable import BrainTones

@MainActor
final class YouTubeViewModelTests: XCTestCase {
    private struct StubService: YouTubeServicing {
        enum Error: Swift.Error {
            case missingPlaylist
        }

        let playlists: [String: YouTubePlaylist]

        func fetchPlaylist(id: String) async throws -> YouTubePlaylist {
            guard let playlist = playlists[id] else {
                throw Error.missingPlaylist
            }
            return playlist
        }
    }

    // MARK: - Helpers

    private func makePlaylist(id: String, title: String) -> YouTubePlaylist {
        let videos = [
            YouTubeVideo(id: "\(id)-video-1", title: "\(title) Track 1", channelTitle: "Channel", thumbnailURL: nil),
            YouTubeVideo(id: "\(id)-video-2", title: "\(title) Track 2", channelTitle: "Channel", thumbnailURL: nil),
            YouTubeVideo(id: "\(id)-video-3", title: "\(title) Track 3", channelTitle: "Channel", thumbnailURL: nil)
        ]
        return YouTubePlaylist(id: id, title: title, videos: videos)
    }

    private func makeViewModel(
        suiteName: String = "BrainTonesTests.YouTube.\(UUID().uuidString)",
        playlists: [String: YouTubePlaylist]? = nil,
        configureSettings: ((SettingsStore) -> Void)? = nil
    ) -> (YouTubeViewModel, SettingsStore, () -> Void) {
        MediaPlaybackCoordinator.shared.resetForTesting()
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let teardown = {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let settings = SettingsStore(defaults: defaults)
        configureSettings?(settings)
        let allPlaylists = playlists ?? ["PLAYLIST_A": makePlaylist(id: "PLAYLIST_A", title: "Alpha Mix")]
        let stub = StubService(playlists: allPlaylists)
        let viewModel = YouTubeViewModel(service: stub, settings: settings, autoRestore: false)
        return (viewModel, settings, teardown)
    }

    private func extractTimer(from viewModel: YouTubeViewModel) -> Timer? {
        let mirror = Mirror(reflecting: viewModel)
        if let timer = mirror.descendant("autoSaveTimer") as? Timer {
            return timer
        }
        return nil
    }

    // MARK: - Tests mirroring tones/test.spec.js behaviour

    func testLoadingPlaylistUpdatesStateAndSettings() async {
        let (viewModel, settings, teardown) = makeViewModel()
        defer { teardown() }

        XCTAssertNil(viewModel.currentPlaylist)
        XCTAssertNil(settings.currentPlaylistId)

        viewModel.playlistURL = "https://www.youtube.com/playlist?list=PLAYLIST_A"
        await viewModel.loadPlaylistFromCurrentURL()

        XCTAssertEqual(viewModel.currentPlaylist?.id, "PLAYLIST_A")
        XCTAssertEqual(viewModel.activePlaylistId, "PLAYLIST_A")
        XCTAssertEqual(settings.currentPlaylistId, "PLAYLIST_A")
        XCTAssertEqual(settings.currentPlaylistURL?.absoluteString, viewModel.playlistURL)
    }

    func testAddingPlaylistToRecentsStoresEntry() async {
        let playlists = [
            "PLAYLIST_A": makePlaylist(id: "PLAYLIST_A", title: "Alpha Mix")
        ]
        let (viewModel, settings, teardown) = makeViewModel(playlists: playlists)
        defer { teardown() }

        viewModel.playlistURL = "https://www.youtube.com/playlist?list=PLAYLIST_A"
        await viewModel.loadPlaylistFromCurrentURL()
        viewModel.addCurrentPlaylistToRecents(named: "Focus Session")

        XCTAssertEqual(settings.recentPlaylists.count, 1)
        let entry = settings.recentPlaylists.first
        XCTAssertEqual(entry?.id, "PLAYLIST_A")
        XCTAssertEqual(entry?.title, "Focus Session")
        XCTAssertEqual(entry?.url.absoluteString, viewModel.playlistURL)
    }

    func testDeletingRecentPlaylistRemovesEntry() async {
        let (viewModel, settings, teardown) = makeViewModel()
        defer { teardown() }

        let playlist = RecentPlaylist(id: "PLAYLIST_A", title: "Alpha Mix", url: URL(string: "https://youtube.com")!)
        settings.addRecentPlaylist(playlist)
        await Task.yield()
        XCTAssertEqual(viewModel.recentPlaylists.count, 1)

        viewModel.deleteRecentPlaylist(playlist)
        await Task.yield()
        XCTAssertTrue(settings.recentPlaylists.isEmpty)
        XCTAssertTrue(viewModel.recentPlaylists.isEmpty)
    }

    func testRestoringExistingPlaylistUsesSavedState() async {
        let playlist = makePlaylist(id: "PLAYLIST_A", title: "Alpha Mix")
        let playlists = ["PLAYLIST_A": playlist]
        let (viewModel, _, teardown) = makeViewModel(playlists: playlists) { settings in
            settings.currentPlaylistId = "PLAYLIST_A"
            settings.currentPlaylistURL = URL(string: "https://www.youtube.com/playlist?list=PLAYLIST_A")
            settings.updatePlaylistState(
                PlaylistPlaybackState(playlistId: "PLAYLIST_A", videoIndex: 2, playbackTime: 45)
            )
        }
        defer { teardown() }

        await viewModel.restoreExistingPlaylist()

        XCTAssertEqual(viewModel.currentPlaylist?.id, "PLAYLIST_A")
        XCTAssertEqual(viewModel.startIndex, 2)
        XCTAssertEqual(viewModel.startTime, 45, accuracy: 0.001)
        XCTAssertFalse(viewModel.isPlayerPlaying)
    }

    func testRestoringPlaylistWithoutSavedStateResetsStartPosition() async {
        let playlists = ["PLAYLIST_A": makePlaylist(id: "PLAYLIST_A", title: "Alpha Mix")]
        let (viewModel, _, teardown) = makeViewModel(playlists: playlists) { settings in
            settings.currentPlaylistId = "PLAYLIST_A"
        }
        defer { teardown() }

        await viewModel.restoreExistingPlaylist()

        XCTAssertEqual(viewModel.startIndex, 0)
        XCTAssertEqual(viewModel.startTime, 0, accuracy: 0.001)
    }

    func testPlaybackPausePersistsState() async throws {
        let (viewModel, settings, teardown) = makeViewModel()
        defer { teardown() }

        viewModel.activePlaylistId = "PLAYLIST_A"
        viewModel.playerProgress(index: 1, time: 32, duration: 300)
        viewModel.playerStateChanged(.paused, index: 1, time: 32)

        let persisted = try XCTUnwrap(settings.playlistState(for: "PLAYLIST_A"))
        XCTAssertEqual(persisted.videoIndex, 1)
        XCTAssertEqual(persisted.playbackTime, 32, accuracy: 0.001)
    }

    func testPlaybackEndedClearsSavedState() async {
        let (viewModel, settings, teardown) = makeViewModel()
        defer { teardown() }

        let state = PlaylistPlaybackState(playlistId: "PLAYLIST_A", videoIndex: 1, playbackTime: 12)
        settings.updatePlaylistState(state)
        viewModel.activePlaylistId = "PLAYLIST_A"

        viewModel.playerStateChanged(.ended, index: 0, time: 0)

        XCTAssertNil(settings.playlistState(for: "PLAYLIST_A"))
    }

    func testSwitchingPlaylistSavesOutgoingState() async throws {
        let playlists = [
            "PLAYLIST_A": makePlaylist(id: "PLAYLIST_A", title: "Alpha Mix"),
            "PLAYLIST_B": makePlaylist(id: "PLAYLIST_B", title: "Beta Beats")
        ]
        let (viewModel, settings, teardown) = makeViewModel(playlists: playlists)
        defer { teardown() }

        viewModel.playlistURL = "https://www.youtube.com/playlist?list=PLAYLIST_A"
        await viewModel.loadPlaylistFromCurrentURL()
        viewModel.playerProgress(index: 2, time: 45, duration: 300)
        viewModel.playerStateChanged(.paused, index: 2, time: 45)

        viewModel.playlistURL = "https://www.youtube.com/playlist?list=PLAYLIST_B"
        await viewModel.loadPlaylistFromCurrentURL()

        let savedState = try XCTUnwrap(settings.playlistState(for: "PLAYLIST_A"))
        XCTAssertEqual(savedState.videoIndex, 2)
        XCTAssertEqual(savedState.playbackTime, 45, accuracy: 0.001)
    }

    func testLoadingRecentPlaylistRestoresSavedStateAndSavesPrevious() async throws {
        let playlists = [
            "PLAYLIST_A": makePlaylist(id: "PLAYLIST_A", title: "Alpha Mix"),
            "PLAYLIST_B": makePlaylist(id: "PLAYLIST_B", title: "Beta Beats")
        ]
        let (viewModel, settings, teardown) = makeViewModel(playlists: playlists)
        defer { teardown() }

        let recentA = RecentPlaylist(id: "PLAYLIST_A", title: "Alpha Mix", url: URL(string: "https://www.youtube.com/playlist?list=PLAYLIST_A")!)
        let recentB = RecentPlaylist(id: "PLAYLIST_B", title: "Beta Beats", url: URL(string: "https://www.youtube.com/playlist?list=PLAYLIST_B")!)
        settings.addRecentPlaylist(recentA)
        settings.addRecentPlaylist(recentB)

        viewModel.playlistURL = recentA.url.absoluteString
        await viewModel.loadPlaylistFromCurrentURL()
        viewModel.playerProgress(index: 1, time: 30, duration: 200)
        viewModel.playerStateChanged(.paused, index: 1, time: 30)

        let savedForA = try XCTUnwrap(settings.playlistState(for: "PLAYLIST_A"))
        XCTAssertEqual(savedForA.videoIndex, 1)

        await viewModel.loadRecentPlaylist(recentB)

        XCTAssertEqual(viewModel.currentPlaylist?.id, "PLAYLIST_B")
        XCTAssertEqual(viewModel.startIndex, 0)
        XCTAssertEqual(viewModel.startTime, 0, accuracy: 0.001)

        settings.updatePlaylistState(
            PlaylistPlaybackState(playlistId: "PLAYLIST_B", videoIndex: 3, playbackTime: 60)
        )
        await viewModel.loadRecentPlaylist(recentB)
        XCTAssertEqual(viewModel.startIndex, 3)
        XCTAssertEqual(viewModel.startTime, 60, accuracy: 0.001)

        // Switching back should preserve B and restore A
        settings.updatePlaylistState(
            PlaylistPlaybackState(playlistId: "PLAYLIST_A", videoIndex: 2, playbackTime: 90)
        )
        await viewModel.loadRecentPlaylist(recentA)
        XCTAssertEqual(viewModel.startIndex, 2)
        XCTAssertEqual(viewModel.startTime, 90, accuracy: 0.001)
    }

    func testAutoSaveTimerStartsAndStopsWithPlayback() async {
        let (viewModel, _, teardown) = makeViewModel()
        defer { teardown() }

        XCTAssertNil(extractTimer(from: viewModel))

        viewModel.playerStateChanged(.playing, index: 0, time: 0)
        XCTAssertNotNil(extractTimer(from: viewModel))

        viewModel.playerStateChanged(.paused, index: 0, time: 1)
        XCTAssertNil(extractTimer(from: viewModel))
    }

    func testPlayerReadyAndPlaybackFlags() async {
        let (viewModel, _, teardown) = makeViewModel()
        defer { teardown() }

        XCTAssertFalse(viewModel.isPlayerReady)
        viewModel.playerReady()
        XCTAssertTrue(viewModel.isPlayerReady)

        viewModel.playerStateChanged(.playing, index: 0, time: 5)
        XCTAssertTrue(viewModel.isPlayerPlaying)

        viewModel.playerStateChanged(.paused, index: 0, time: 6)
        XCTAssertFalse(viewModel.isPlayerPlaying)

        viewModel.playerStateChanged(.ended, index: 1, time: 0)
        XCTAssertFalse(viewModel.isPlayerPlaying)
    }
}
