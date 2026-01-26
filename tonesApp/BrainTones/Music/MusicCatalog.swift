import Foundation

struct AudioTrack: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let duration: TimeInterval?
    let remoteURL: URL
    var localURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case duration
        case remoteURL
        case localURL
    }

    init(id: String, title: String, duration: TimeInterval?, remoteURL: URL, localURL: URL? = nil) {
        self.id = id
        self.title = title
        self.duration = duration
        self.remoteURL = remoteURL
        self.localURL = localURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        remoteURL = try container.decode(URL.self, forKey: .remoteURL)
        localURL = try container.decodeIfPresent(URL.self, forKey: .localURL)

        if let explicitTitle = try container.decodeIfPresent(String.self, forKey: .title),
           !explicitTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = explicitTitle
        } else {
            title = Self.inferTitle(from: remoteURL, fallback: id)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encode(remoteURL, forKey: .remoteURL)
        try container.encodeIfPresent(localURL, forKey: .localURL)
    }
}

private extension AudioTrack {
    static func inferTitle(from url: URL, fallback: String) -> String {
        let raw = url.deletingPathExtension().lastPathComponent
        let plusReplaced = raw.replacingOccurrences(of: "+", with: " ")
        let decoded = plusReplaced.removingPercentEncoding ?? plusReplaced
        let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

struct AudioPlaylist: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let defaultStartIndex: Int
    let tracks: [AudioTrack]
}

private struct CatalogContainer: Codable {
    let playlists: [AudioPlaylist]
}

protocol MusicCatalogServicing {
    func loadCatalog() throws -> [AudioPlaylist]
}

final class MusicCatalogService: MusicCatalogServicing {
    enum Error: Swift.Error {
        case missingResource
        case decodingFailed(Swift.Error)
    }

    private let bundle: Bundle
    private let resourceName: String
    private let decoder: JSONDecoder

    init(bundle: Bundle = .main, resourceName: String = "music_playlists", decoder: JSONDecoder = JSONDecoder()) {
        self.bundle = bundle
        self.resourceName = resourceName
        self.decoder = decoder
    }

    func loadCatalog() throws -> [AudioPlaylist] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw Error.missingResource
        }

        do {
            let data = try Data(contentsOf: url)
            let container = try decoder.decode(CatalogContainer.self, from: data)
            return container.playlists
        } catch {
            throw Error.decodingFailed(error)
        }
    }
}
