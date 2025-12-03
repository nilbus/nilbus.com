import XCTest
@testable import BrainTones

final class SettingsStoreTests: XCTestCase {
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "BrainTonesTests.SettingsStore.\(UUID().uuidString)"
    }

    override func tearDown() {
        if let suiteName {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        suiteName = nil
        super.tearDown()
    }

    func testPersistingOutputMode() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.outputMode, .headphones)
        store.outputMode = .speakers

        let newStore = SettingsStore(defaults: defaults)
        XCTAssertEqual(newStore.outputMode, .speakers)
    }

    func testMusicPlaybackStatePersistence() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SettingsStore(defaults: defaults)
        let state = MusicPlaybackState(playlistId: "focus", trackIndex: 3, playbackTime: 42.5)
        store.updatePlaybackState(state)

        guard let persisted = store.playbackState(for: "focus") else {
            return XCTFail("Expected persisted state for playlist")
        }

        XCTAssertEqual(persisted.trackIndex, state.trackIndex)
        XCTAssertEqual(persisted.playbackTime, state.playbackTime, accuracy: 0.01)

        store.removePlaybackState(for: "focus")
        XCTAssertNil(store.playbackState(for: "focus"))
    }

    func testRecentPlaylistCustomNamePersistence() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SettingsStore(defaults: defaults)

        store.updateRecentPlaylist(id: "focus", customName: "Deep Work Mix")
        XCTAssertEqual(store.recentPlaylists.count, 1)
        XCTAssertEqual(store.recentPlaylists.first?.playlistId, "focus")
        XCTAssertEqual(store.recentPlaylists.first?.customName, "Deep Work Mix")

        store.updateRecentPlaylist(id: "focus", customName: nil)
        XCTAssertNil(store.recentPlaylists.first?.customName)

        store.removeRecentPlaylist(withId: "focus")
        XCTAssertTrue(store.recentPlaylists.isEmpty)
    }

    func testCachedTrackFileNamesPersist() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SettingsStore(defaults: defaults)

        store.updateCachedFileName("alliespaces-track-01.mp3", for: "track-01")
        XCTAssertEqual(store.cachedFileName(for: "track-01"), "alliespaces-track-01.mp3")

        store.removeCachedFileName(for: "track-01")
        XCTAssertNil(store.cachedFileName(for: "track-01"))
    }
}
