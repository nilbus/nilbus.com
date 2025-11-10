import Foundation
import Combine

struct PlaylistPlaybackState: Codable, Hashable {
    var playlistId: String
    var videoIndex: Int
    var playbackTime: Double
}

struct RecentPlaylist: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var url: URL
    var addedAt: Date

    init(id: String, title: String, url: URL, addedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.url = url
        self.addedAt = addedAt
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

    @Published var currentPlaylistURL: URL? {
        didSet { save(currentPlaylistURL?.absoluteString, for: .currentPlaylistURL) }
    }

    @Published var playlistStates: [String: PlaylistPlaybackState] {
        didSet { saveCodable(playlistStates, for: .playlistStates) }
    }

    @Published var recentPlaylists: [RecentPlaylist] {
        didSet { saveCodable(recentPlaylists, for: .recentPlaylists) }
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

        if let urlString = defaults.string(forKey: DefaultsKey.currentPlaylistURL.rawValue),
           let url = URL(string: urlString) {
            currentPlaylistURL = url
        } else {
            currentPlaylistURL = nil
        }

        playlistStates = SettingsStore.loadCodable([String: PlaylistPlaybackState].self, for: .playlistStates, decoder: decoder, defaults: defaults) ?? [:]
        recentPlaylists = SettingsStore.loadCodable([RecentPlaylist].self, for: .recentPlaylists, decoder: decoder, defaults: defaults) ?? []
    }

    func playlistState(for playlistId: String) -> PlaylistPlaybackState? {
        playlistStates[playlistId]
    }

    func updatePlaylistState(_ state: PlaylistPlaybackState) {
        playlistStates[state.playlistId] = state
    }

    func removePlaylistState(for playlistId: String) {
        playlistStates.removeValue(forKey: playlistId)
    }

    func addRecentPlaylist(_ playlist: RecentPlaylist) {
        recentPlaylists.removeAll { $0.id == playlist.id }
        recentPlaylists.insert(playlist, at: 0)
        recentPlaylists = Array(recentPlaylists.prefix(20))
    }

    func removeRecentPlaylist(withId id: String) {
        recentPlaylists.removeAll { $0.id == id }
    }
}

private extension SettingsStore {
    enum DefaultsKey: String {
        case outputMode = "brainTones.outputMode"
        case lastPresetName = "brainTones.lastPresetName"
        case currentPlaylistId = "brainTones.youtube.playlistId"
        case currentPlaylistURL = "brainTones.youtube.playlistURL"
        case playlistStates = "brainTones.youtube.playlistStates"
        case recentPlaylists = "brainTones.youtube.recentPlaylists"
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

    static func loadCodable<T: Decodable>(_ type: T.Type, for key: DefaultsKey, decoder: JSONDecoder, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Failed to decode \\(T.self) for \\(key.rawValue): \\(error)")
            return nil
        }
    }
}
