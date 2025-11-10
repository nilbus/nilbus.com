import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    @Binding var playlistId: String?
    @Binding var isPlaying: Bool
    var startIndex: Int
    var startTime: Double

    let onReady: () -> Void
    let onStateChange: (YouTubePlayerState, Int, Double) -> Void
    let onProgress: (Int, Double, Double) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            playlistId: playlistId,
            startIndex: startIndex,
            startTime: startTime,
            onReady: onReady,
            onStateChange: onStateChange,
            onProgress: onProgress,
            onError: onError
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.setValue(true, forKey: "allowsPictureInPictureMediaPlayback")
        configuration.applicationNameForUserAgent = "BrainTones"
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(context.coordinator, name: "bridge")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false

        if let htmlURL = Bundle.main.url(forResource: "youtube_player", withExtension: "html"),
           let htmlString = try? String(contentsOf: htmlURL, encoding: .utf8) {
            webView.loadHTMLString(htmlString, baseURL: URL(string: "https://www.youtube.com"))
        }

        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.update(
            playlistId: playlistId,
            startIndex: startIndex,
            startTime: startTime,
            isPlaying: isPlaying
        )
    }
}

extension YouTubePlayerView {
    final class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?

        private var pendingPlaylistId: String?
        private var pendingStartIndex: Int = 0
        private var pendingStartTime: Double = 0
        private var isPlaying: Bool = false
        private var isReady = false
        private var currentPlaylistId: String?

        private let onReady: () -> Void
        private let onStateChange: (YouTubePlayerState, Int, Double) -> Void
        private let onProgress: (Int, Double, Double) -> Void
        private let onError: (String) -> Void

        init(
            playlistId: String?,
            startIndex: Int,
            startTime: Double,
            onReady: @escaping () -> Void,
            onStateChange: @escaping (YouTubePlayerState, Int, Double) -> Void,
            onProgress: @escaping (Int, Double, Double) -> Void,
            onError: @escaping (String) -> Void
        ) {
            self.pendingPlaylistId = playlistId
            self.pendingStartIndex = startIndex
            self.pendingStartTime = startTime
            self.onReady = onReady
            self.onStateChange = onStateChange
            self.onProgress = onProgress
            self.onError = onError
        }

        func update(playlistId: String?, startIndex: Int, startTime: Double, isPlaying: Bool) {
            if let playlistId, playlistId != currentPlaylistId {
                loadPlaylist(playlistId: playlistId, index: startIndex, time: startTime)
            }

            if isPlaying != self.isPlaying {
                self.isPlaying = isPlaying
                sendPlaybackCommand(shouldPlay: isPlaying)
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "bridge" else { return }

            if let body = message.body as? String,
               let data = body.data(using: .utf8) {
                handleMessageData(data)
            }
        }

        private func handleMessageData(_ data: Data) {
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }

            guard let type = json["type"] as? String else {
                return
            }

            switch type {
            case "ready":
                isReady = true
                onReady()
                if let playlistId = pendingPlaylistId {
                    loadPlaylist(playlistId: playlistId, index: pendingStartIndex, time: pendingStartTime)
                    pendingPlaylistId = nil
                }
                sendPlaybackCommand(shouldPlay: isPlaying)

            case "stateChange":
                let stateValue = (json["state"] as? Int) ?? YouTubePlayerState.unstarted.rawValue
                let state = YouTubePlayerState(rawValue: stateValue) ?? .unstarted
                let index = json["index"] as? Int ?? 0
                let time = json["time"] as? Double ?? 0
                onStateChange(state, index, time)

            case "progress":
                let index = json["index"] as? Int ?? 0
                let time = json["time"] as? Double ?? 0
                let duration = json["duration"] as? Double ?? 0
                onProgress(index, time, duration)

            case "error":
                let message = json["message"] as? String ?? "YouTube player error."
                if let code = json["code"] as? Int {
                    onError("\(message) (code \(code))")
                } else {
                    onError(message)
                }

            case "playlistLoaded":
                if let playlistId = json["playlistId"] as? String {
                    currentPlaylistId = playlistId
                }

            default:
                break
            }
        }

        private func loadPlaylist(playlistId: String, index: Int, time: Double) {
            guard let webView else {
                pendingPlaylistId = playlistId
                pendingStartIndex = index
                pendingStartTime = time
                return
            }

            if !isReady {
                pendingPlaylistId = playlistId
                pendingStartIndex = index
                pendingStartTime = time
                return
            }

            let script = "nativeLoadPlaylist('\(playlistId)', \(index), \(time));"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        private func sendPlaybackCommand(shouldPlay: Bool) {
            guard isReady, let webView else { return }
            let command = shouldPlay ? "nativePlay();" : "nativePause();"
            webView.evaluateJavaScript(command, completionHandler: nil)
        }
    }
}
