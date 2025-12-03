import Combine
import XCTest
@testable import BrainTones

@MainActor
final class MusicPlayerViewModelTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        MediaPlaybackCoordinator.shared.resetForTesting()
        super.tearDown()
    }

    func testCatalogLoadConfiguresInitialPlaylist() async throws {
        let playlists = [makePlaylist(id: "focus", title: "Focus Mix")]
        let catalog = StubCatalogService(playlists: playlists)
        let controller = StubPlaybackController()
        let suite = "MusicPlayerViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)

        let viewModel = MusicPlayerViewModel(
            catalogService: catalog,
            controller: controller,
            settings: settings,
            autoRestore: false
        )

        try await waitForPlaylists(toLoad: viewModel)

        XCTAssertEqual(viewModel.playlists.count, 1)
        XCTAssertEqual(viewModel.selectedPlaylist?.id, "focus")
        XCTAssertEqual(controller.configureCalls.count, 1)
        XCTAssertEqual(controller.configureCalls.first?.playlist.id, "focus")
    }

    func testSelectingTrackUpdatesPlaybackState() async throws {
        let playlists = [makePlaylist(id: "focus", title: "Focus Mix")]
        let catalog = StubCatalogService(playlists: playlists)
        let controller = StubPlaybackController()
        let suite = "MusicPlayerViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)

        let viewModel = MusicPlayerViewModel(
            catalogService: catalog,
            controller: controller,
            settings: settings,
            autoRestore: false
        )

        try await waitForPlaylists(toLoad: viewModel)

        viewModel.selectTrack(at: 1, autoplay: true)
        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(controller.selectTrackCalls.count, 1)
        XCTAssertEqual(viewModel.currentTrackIndex, 1)
        XCTAssertTrue(controller.state.isPlaying)
    }

    func testAddingPlaylistToRecentsStoresCustomName() async throws {
        let playlists = [makePlaylist(id: "focus", title: "Focus Mix")]
        let catalog = StubCatalogService(playlists: playlists)
        let controller = StubPlaybackController()
        let suite = "MusicPlayerViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)

        let viewModel = MusicPlayerViewModel(
            catalogService: catalog,
            controller: controller,
            settings: settings,
            autoRestore: false
        )

        try await waitForPlaylists(toLoad: viewModel)

        viewModel.addSelectedPlaylistToRecents(customName: "Deep Work")
        XCTAssertEqual(settings.recentPlaylists.first?.playlistId, "focus")
        XCTAssertEqual(settings.recentPlaylists.first?.customName, "Deep Work")
    }
}

// MARK: - Helpers

private extension MusicPlayerViewModelTests {
    func waitForPlaylists(toLoad viewModel: MusicPlayerViewModel) async {
        if !viewModel.playlists.isEmpty { return }

        let expectation = XCTestExpectation(description: "Playlists loaded")
        viewModel.$playlists
            .dropFirst()
            .sink { playlists in
                if !playlists.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func makePlaylist(id: String, title: String) -> AudioPlaylist {
        let tracks = [
            AudioTrack(id: "\(id)-01", title: "\(title) Track 1", duration: 180, remoteURL: URL(string: "https://example.com/\(id)/1.mp3")!),
            AudioTrack(id: "\(id)-02", title: "\(title) Track 2", duration: 200, remoteURL: URL(string: "https://example.com/\(id)/2.mp3")!)
        ]
        return AudioPlaylist(id: id, title: title, defaultStartIndex: 0, tracks: tracks)
    }

}

// MARK: - Stubs

private final class StubCatalogService: MusicCatalogServicing {
    private let playlists: [AudioPlaylist]

    init(playlists: [AudioPlaylist]) {
        self.playlists = playlists
    }

    func loadCatalog() throws -> [AudioPlaylist] {
        playlists
    }
}

@MainActor
private final class StubPlaybackController: MusicPlaybackControlling {
    private let stateSubject = CurrentValueSubject<MusicPlayerRuntimeState, Never>(.empty)

    var state: MusicPlayerRuntimeState {
        stateSubject.value
    }

    var statePublisher: AnyPublisher<MusicPlayerRuntimeState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    private(set) var configureCalls: [(playlist: AudioPlaylist, index: Int, time: TimeInterval, autoplay: Bool)] = []
    private(set) var selectTrackCalls: [Int] = []
    private(set) var playCalls = 0
    private(set) var pauseCalls = 0

    func configure(with playlist: AudioPlaylist, startIndex: Int, startTime: TimeInterval, autoplay: Bool) {
        configureCalls.append((playlist, startIndex, startTime, autoplay))
        var newState = state
        newState.playlist = playlist
        newState.trackIndex = min(max(startIndex, 0), playlist.tracks.count - 1)
        newState.track = playlist.tracks[newState.trackIndex]
        newState.position = startTime
        newState.isPlaying = autoplay
        stateSubject.send(newState)
    }

    func play() {
        playCalls += 1
        updateState { state in
            var state = state
            state.isPlaying = true
            return state
        }
    }

    func pause() {
        pauseCalls += 1
        updateState { state in
            var state = state
            state.isPlaying = false
            return state
        }
    }

    func togglePlayback() {
        if state.isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to time: TimeInterval) {
        updateState { state in
            var state = state
            state.position = time
            return state
        }
    }

    func skipForward() {
        guard let playlist = state.playlist else { return }
        let nextIndex = min(state.trackIndex + 1, playlist.tracks.count - 1)
        selectTrack(at: nextIndex, startTime: 0, autoplay: state.isPlaying)
    }

    func skipBackward() {
        guard let playlist = state.playlist else { return }
        let prevIndex = max(state.trackIndex - 1, 0)
        selectTrack(at: prevIndex, startTime: 0, autoplay: state.isPlaying)
    }

    func selectTrack(at index: Int, startTime: TimeInterval, autoplay: Bool) {
        selectTrackCalls.append(index)
        updateState { current in
            guard let playlist = current.playlist,
                  playlist.tracks.indices.contains(index) else { return current }
            var updated = current
            updated.trackIndex = index
            updated.track = playlist.tracks[index]
            updated.position = startTime
            updated.isPlaying = autoplay
            return updated
        }
    }

    private func updateState(_ transform: (MusicPlayerRuntimeState) -> MusicPlayerRuntimeState) {
        let newState = transform(stateSubject.value)
        stateSubject.send(newState)
    }
}
