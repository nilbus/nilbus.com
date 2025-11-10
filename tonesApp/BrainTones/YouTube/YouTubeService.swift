import Foundation

protocol YouTubeServicing {
    func fetchPlaylist(id: String) async throws -> YouTubePlaylist
}

final class YouTubeService: YouTubeServicing {
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func fetchPlaylist(id: String) async throws -> YouTubePlaylist {
        async let metadataTask = fetchPlaylistMetadata(id: id)
        async let videosTask = fetchPlaylistVideos(id: id)

        let (title, videos) = try await (metadataTask, videosTask)
        return YouTubePlaylist(id: id, title: title, videos: videos)
    }
}

private extension YouTubeService {
    struct PlaylistResponse: Decodable {
        let items: [PlaylistItem]
    }

    struct PlaylistItem: Decodable {
        let snippet: PlaylistSnippet
    }

    struct PlaylistSnippet: Decodable {
        let title: String
    }

    struct PlaylistVideosResponse: Decodable {
        let items: [PlaylistVideoItem]
        let nextPageToken: String?
    }

    struct PlaylistVideoItem: Decodable {
        let contentDetails: ContentDetails
        let snippet: VideoSnippet
    }

    struct ContentDetails: Decodable {
        let videoId: String
    }

    struct VideoSnippet: Decodable {
        let title: String
        let videoOwnerChannelTitle: String?
        let thumbnails: Thumbnails?
    }

    struct Thumbnails: Decodable {
        let medium: ThumbnailInfo?
        let high: ThumbnailInfo?
        let standard: ThumbnailInfo?
        let maxres: ThumbnailInfo?
    }

    struct ThumbnailInfo: Decodable {
        let url: URL
    }

    func fetchPlaylistMetadata(id: String) async throws -> String {
        guard var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlists") else {
            throw YouTubeError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components.url else {
            throw YouTubeError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)
            try validate(response: response, data: data)
            let playlist = try JSONDecoder().decode(PlaylistResponse.self, from: data)
            guard let title = playlist.items.first?.snippet.title else {
                throw YouTubeError.api(message: "The playlist is unavailable.")
            }
            return title
        } catch let error as YouTubeError {
            throw error
        } catch {
            throw YouTubeError.networking(error)
        }
    }

    func fetchPlaylistVideos(id: String) async throws -> [YouTubeVideo] {
        var videos: [YouTubeVideo] = []
        var pageToken: String?
        var iterations = 0

        repeat {
            iterations += 1
            guard iterations < 20 else { break } // Safety cap (~1000 videos)

            guard var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlistItems") else {
                throw YouTubeError.invalidURL
            }

            var queryItems = [
                URLQueryItem(name: "part", value: "snippet,contentDetails"),
                URLQueryItem(name: "playlistId", value: id),
                URLQueryItem(name: "maxResults", value: "50"),
                URLQueryItem(name: "key", value: apiKey)
            ]
            if let token = pageToken {
                queryItems.append(URLQueryItem(name: "pageToken", value: token))
            }
            components.queryItems = queryItems

            guard let url = components.url else {
                throw YouTubeError.invalidURL
            }

            do {
                let (data, response) = try await session.data(from: url)
                try validate(response: response, data: data)
                let chunk = try JSONDecoder().decode(PlaylistVideosResponse.self, from: data)
                pageToken = chunk.nextPageToken

                let mapped = chunk.items.compactMap { item -> YouTubeVideo? in
                    let videoId = item.contentDetails.videoId
                    guard !videoId.isEmpty else { return nil }
                    let snippet = item.snippet
                    let thumbnailURL = snippet.thumbnails?.maxres?.url
                        ?? snippet.thumbnails?.standard?.url
                        ?? snippet.thumbnails?.high?.url
                        ?? snippet.thumbnails?.medium?.url

                    return YouTubeVideo(
                        id: videoId,
                        title: snippet.title,
                        channelTitle: snippet.videoOwnerChannelTitle ?? "",
                        thumbnailURL: thumbnailURL
                    )
                }

                videos.append(contentsOf: mapped)
            } catch let error as YouTubeError {
                throw error
            } catch {
                throw YouTubeError.networking(error)
            }
        } while pageToken != nil

        return videos
    }

    func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw YouTubeError.api(message: message)
            }
            throw YouTubeError.api(message: "YouTube returned an error (code \(http.statusCode)).")
        }
    }
}
