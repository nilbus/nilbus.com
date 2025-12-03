import Foundation
import Combine

struct MusicPlaybackState: Codable, Hashable {
    var playlistId: String
    var trackIndex: Int
    var playbackTime: TimeInterval
}

struct MusicRecentPlaylist: Codable, Identifiable, Hashable {
    var playlistId: String
    var customName: String?
    var lastPlayedAt: Date

    var id: String { playlistId }

    init(playlistId: String, customName: String? = nil, lastPlayedAt: Date = Date()) {
        self.playlistId = playlistId
        self.customName = customName
        self.lastPlayedAt = lastPlayedAt
    }
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var outputMode: OutputMode {
        didSet { save(outputMode.rawValue, for: .outputMode) }
    }

    @Published var lastPresetName: String? {
        didSet { save(lastPresetName, for: .lastPresetName) }
    }

    @Published var currentPlaylistId: String? {
        didSet { save(currentPlaylistId, for: .currentPlaylistId) }
    }

    @Published var playlistStates: [String: MusicPlaybackState] {
        didSet { saveCodable(playlistStates, for: .playlistStates) }
    }

    @Published var recentPlaylists: [MusicRecentPlaylist] {
        didSet { saveCodable(recentPlaylists, for: .recentPlaylists) }
    }

    @Published var cachedTrackFileNames: [String: String] {
        didSet { saveCodable(cachedTrackFileNames, for: .cachedTrackFileNames) }
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let storedMode = defaults.string(forKey: DefaultsKey.outputMode.rawValue),
           let mode = OutputMode(rawValue: storedMode) {
            outputMode = mode
        } else {
            outputMode = .headphones
        }

        lastPresetName = defaults.string(forKey: DefaultsKey.lastPresetName.rawValue)
        currentPlaylistId = defaults.string(forKey: DefaultsKey.currentPlaylistId.rawValue)

        playlistStates = SettingsStore.loadCodable(
            [String: MusicPlaybackState].self,
            for: .playlistStates,
            decoder: decoder,
            defaults: defaults
        ) ?? [:]

        recentPlaylists = SettingsStore.loadCodable(
            [MusicRecentPlaylist].self,
            for: .recentPlaylists,
            decoder: decoder,
            defaults: defaults
        ) ?? []

        cachedTrackFileNames = SettingsStore.loadCodable(
            [String: String].self,
            for: .cachedTrackFileNames,
            decoder: decoder,
            defaults: defaults
        ) ?? [:]
    }

    // MARK: - Playback State

    func playbackState(for playlistId: String) -> MusicPlaybackState? {
        playlistStates[playlistId]
    }

    func updatePlaybackState(_ state: MusicPlaybackState) {
        playlistStates[state.playlistId] = state
    }

    func removePlaybackState(for playlistId: String) {
        playlistStates.removeValue(forKey: playlistId)
    }

    // MARK: - Recents

    func updateRecentPlaylist(id: String, customName: String?) {
        let updated = MusicRecentPlaylist(playlistId: id, customName: customName, lastPlayedAt: Date())
        recentPlaylists.removeAll { $0.playlistId == id }
        recentPlaylists.insert(updated, at: 0)
        recentPlaylists = Array(recentPlaylists.prefix(20))
    }

    func removeRecentPlaylist(withId id: String) {
        recentPlaylists.removeAll { $0.playlistId == id }
    }

    // MARK: - Cached Tracks

    func cachedFileName(for trackId: String) -> String? {
        cachedTrackFileNames[trackId]
    }

    func updateCachedFileName(_ fileName: String, for trackId: String) {
        cachedTrackFileNames[trackId] = fileName
    }

    func removeCachedFileName(for trackId: String) {
        cachedTrackFileNames.removeValue(forKey: trackId)
    }
}

private extension SettingsStore {
    enum DefaultsKey: String {
        case outputMode = "brainTones.outputMode"
        case lastPresetName = "brainTones.lastPresetName"
        case currentPlaylistId = "brainTones.music.playlistId"
        case playlistStates = "brainTones.music.playbackStates"
        case recentPlaylists = "brainTones.music.recentPlaylists"
        case cachedTrackFileNames = "brainTones.music.cachedTrackFileNames"
    }

    func save(_ value: String?, for key: DefaultsKey) {
        defaults.set(value, forKey: key.rawValue)
    }

    func saveCodable<T: Encodable>(_ value: T, for key: DefaultsKey) {
        do {
            let data = try encoder.encode(value)
            defaults.set(data, forKey: key.rawValue)
        } catch {
            print("Failed to encode \\(T.self) for \\(key.rawValue): \\(error)")
        }
    }

    static func loadCodable<T: Decodable>(
        _ type: T.Type,
        for key: DefaultsKey,
        decoder: JSONDecoder,
        defaults: UserDefaults
    ) -> T? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Failed to decode \\(T.self) for \\(key.rawValue): \\(error)")
            return nil
        }
    }
}
