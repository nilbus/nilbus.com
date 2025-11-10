import XCTest
@testable import BrainTones

@MainActor
final class YouTubeViewModelTests: XCTestCase {
    private struct StubService: YouTubeServicing {
        let playlist: YouTubePlaylist

        func fetchPlaylist(id: String) async throws -> YouTubePlaylist {
            playlist
        }
    }

    private func makeViewModel(defaultsSuite: String) -> (YouTubeViewModel, SettingsStore) {
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        let settings = SettingsStore(defaults: defaults)
        let videos = [
            YouTubeVideo(id: "video1", title: "First", channelTitle: "Channel", thumbnailURL: nil),
            YouTubeVideo(id: "video2", title: "Second", channelTitle: "Channel", thumbnailURL: nil)
        ]
        let playlist = YouTubePlaylist(id: "PLAYLIST_ID", title: "Focus Mix", videos: videos)
        let stub = StubService(playlist: playlist)
        let viewModel = YouTubeViewModel(service: stub, settings: settings, autoRestore: false)
        return (viewModel, settings)
    }

    func testLoadingPlaylistUpdatesStateAndRecents() async {
        let suite = "BrainTonesTests.YouTubeViewModel.\(UUID().uuidString)"
        let (viewModel, settings) = makeViewModel(defaultsSuite: suite)
        XCTAssertTrue(viewModel.recentPlaylists.isEmpty)

        viewModel.playlistURL = "https://www.youtube.com/playlist?list=PLAYLIST_ID"
        await viewModel.loadPlaylistFromCurrentURL()

        XCTAssertEqual(viewModel.activePlaylistId, "PLAYLIST_ID")
        XCTAssertEqual(viewModel.currentPlaylist?.videos.count ?? 0, 2)

        viewModel.addCurrentPlaylistToRecents(named: "My Mix")
        XCTAssertEqual(settings.recentPlaylists.count, 1)
        XCTAssertEqual(settings.recentPlaylists.first?.title, "My Mix")
    }

    func testProgressUpdatesPersistPlaybackState() async {
        let suite = "BrainTonesTests.YouTubeViewModel.Progress.\(UUID().uuidString)"
        let (viewModel, settings) = makeViewModel(defaultsSuite: suite)

        viewModel.activePlaylistId = "PLAYLIST_ID"
        viewModel.playerProgress(index: 1, time: 32.0, duration: 300)
        viewModel.playerStateChanged(.paused, index: 1, time: 32.0)

        guard let persisted = settings.playlistState(for: "PLAYLIST_ID") else {
            return XCTFail("Expected persisted playback state")
        }
        XCTAssertEqual(persisted.videoIndex, 1)
        XCTAssertEqual(persisted.playbackTime, 32.0, accuracy: 0.01)
    }
}
