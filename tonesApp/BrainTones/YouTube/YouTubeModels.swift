import Foundation

struct YouTubeVideo: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let channelTitle: String
    let thumbnailURL: URL?
}

struct YouTubePlaylist: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let videos: [YouTubeVideo]
}

enum YouTubeError: Error, LocalizedError {
    case invalidURL
    case invalidPlaylistId
    case api(message: String)
    case networking(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The playlist URL is invalid."
        case .invalidPlaylistId:
            return "Could not extract a playlist ID from the provided URL."
        case .api(let message):
            return message
        case .networking(let error):
            return error.localizedDescription
        case .decoding:
            return "Failed to parse the response from YouTube."
        }
    }
}

enum YouTubePlayerState: Int {
    case unstarted = -1
    case ended = 0
    case playing = 1
    case paused = 2
    case buffering = 3
    case cued = 5
}

func extractPlaylistId(from urlString: String) -> String? {
    guard let url = URL(string: urlString),
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let queryItems = components.queryItems else {
        return nil
    }

    if let listItem = queryItems.first(where: { $0.name == "list" })?.value {
        return listItem
    }

    // Handle cases like youtube.com/playlist/PL... or share links
    if let path = components.path.split(separator: "/").last,
       path.hasPrefix("PL") {
        return String(path)
    }

    return nil
}
