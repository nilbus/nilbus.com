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

    func testPlaylistStatePersistence() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SettingsStore(defaults: defaults)
        let state = PlaylistPlaybackState(playlistId: "abc", videoIndex: 2, playbackTime: 42.5)
        store.updatePlaylistState(state)

        guard let persisted = store.playlistState(for: "abc") else {
            return XCTFail("Expected persisted state for playlist")
        }

        XCTAssertEqual(persisted.videoIndex, state.videoIndex)
        XCTAssertEqual(persisted.playbackTime, state.playbackTime, accuracy: 0.01)
    }
}
