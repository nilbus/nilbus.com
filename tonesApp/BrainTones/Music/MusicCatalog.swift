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
