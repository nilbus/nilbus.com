import SwiftUI
import UIKit

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
            initialPlaylistId: playlistId,
            initialStartIndex: startIndex,
            initialStartTime: startTime,
            initialAutoplay: isPlaying,
            onReady: onReady,
            onStateChange: onStateChange,
            onProgress: onProgress,
            onError: onError
        )
    }

    func makeUIView(context: Context) -> YTPlayerView {
        let playerView = YTPlayerView()
        configure(playerView)
        context.coordinator.attach(playerView: playerView)
        context.coordinator.update(
            playlistId: playlistId,
            startIndex: startIndex,
            startTime: startTime,
            isPlaying: isPlaying
        )
        return playerView
    }

    func updateUIView(_ uiView: YTPlayerView, context: Context) {
        configure(uiView)
        context.coordinator.attach(playerView: uiView)
        context.coordinator.update(
            playlistId: playlistId,
            startIndex: startIndex,
            startTime: startTime,
            isPlaying: isPlaying
        )
    }
}

private extension YouTubePlayerView {
    func configure(_ playerView: YTPlayerView) {
        if let webView = playerView.webView {
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.scrollView.isScrollEnabled = false
            webView.scrollView.bounces = false
            let configuration = webView.configuration
            configuration.allowsInlineMediaPlayback = true
            configuration.allowsAirPlayForMediaPlayback = true
            if #available(iOS 9.0, *) {
                configuration.allowsPictureInPictureMediaPlayback = true
            }
            if #available(iOS 10.0, *) {
                configuration.mediaTypesRequiringUserActionForPlayback = []
            }
        }
        playerView.backgroundColor = .clear
    }
}

extension YouTubePlayerView {
    final class Coordinator: NSObject, YTPlayerViewDelegate {
        private weak var playerView: YTPlayerView?
        private var isReady = false
        private var desiredIsPlaying: Bool
        private var pendingPlaylistId: String?
        private var pendingStartIndex: Int
        private var pendingStartTime: Double
        private var pendingAutoplay: Bool
        private var currentPlaylistId: String?
        private var lastAppliedIndex: Int
        private var lastAppliedStartTime: Double
        private var lastReportedIndex: Int = 0
        private var currentState: YouTubePlayerState = .unstarted

        private let onReady: () -> Void
        private let onStateChange: (YouTubePlayerState, Int, Double) -> Void
        private let onProgress: (Int, Double, Double) -> Void
        private let onError: (String) -> Void

        init(
            initialPlaylistId: String?,
            initialStartIndex: Int,
            initialStartTime: Double,
            initialAutoplay: Bool,
            onReady: @escaping () -> Void,
            onStateChange: @escaping (YouTubePlayerState, Int, Double) -> Void,
            onProgress: @escaping (Int, Double, Double) -> Void,
            onError: @escaping (String) -> Void
        ) {
            pendingPlaylistId = initialPlaylistId
            pendingStartIndex = initialStartIndex
            pendingStartTime = initialStartTime
            pendingAutoplay = initialAutoplay
            desiredIsPlaying = initialAutoplay
            currentPlaylistId = nil
            lastAppliedIndex = initialStartIndex
            lastAppliedStartTime = initialStartTime
            self.onReady = onReady
            self.onStateChange = onStateChange
            self.onProgress = onProgress
            self.onError = onError
        }

        func attach(playerView: YTPlayerView) {
            guard self.playerView !== playerView else { return }
            self.playerView = playerView
            playerView.delegate = self
        }

        func update(playlistId: String?, startIndex: Int, startTime: Double, isPlaying: Bool) {
            desiredIsPlaying = isPlaying

            guard let playlistId, !playlistId.isEmpty else {
                pendingPlaylistId = nil
                currentPlaylistId = nil
                currentState = .unstarted
                playerView?.stopVideo()
                return
            }

            let isNewPlaylist = playlistId != currentPlaylistId
            let indexChanged = !isNewPlaylist && startIndex != lastAppliedIndex
            let timeChanged = !isNewPlaylist && abs(startTime - lastAppliedStartTime) > 0.5

            if isNewPlaylist || indexChanged || timeChanged || pendingPlaylistId != nil {
                enqueueLoad(
                    playlistId: playlistId,
                    index: startIndex,
                    time: startTime,
                    autoplay: isPlaying
                )
            }

            performPendingLoadIfPossible()
            applyPlaybackIfReady()
        }

        private func enqueueLoad(playlistId: String, index: Int, time: Double, autoplay: Bool) {
            pendingPlaylistId = playlistId
            pendingStartIndex = index
            pendingStartTime = time
            pendingAutoplay = autoplay
            currentState = .unstarted
            if playlistId != currentPlaylistId {
                currentPlaylistId = nil
            }
        }

        private func performPendingLoadIfPossible() {
            guard let playerView,
                  let playlistId = pendingPlaylistId else { return }

            let vars = Self.makePlayerVars(
                startIndex: pendingStartIndex,
                startTime: pendingStartTime,
                autoplay: pendingAutoplay
            )

            if playerView.load(withPlaylistId: playlistId, playerVars: vars) {
                currentPlaylistId = playlistId
                lastAppliedIndex = pendingStartIndex
                lastAppliedStartTime = pendingStartTime
                pendingPlaylistId = nil
            }
        }

        private func applyPlaybackIfReady() {
            guard isReady, currentPlaylistId != nil, let playerView else { return }
            switch (desiredIsPlaying, currentState) {
            case (true, .paused), (true, .unstarted), (true, .cued), (true, .ended), (true, .buffering):
                playerView.playVideo()
            case (false, .playing):
                playerView.pauseVideo()
            default:
                break
            }
        }

        func playerViewDidBecomeReady(_ playerView: YTPlayerView) {
            isReady = true
            onReady()
            performPendingLoadIfPossible()
            applyPlaybackIfReady()
        }

        func playerView(_ playerView: YTPlayerView, didChangeTo state: YTPlayerState) {
            let mappedState = mapState(state)
            currentState = mappedState

            capturePlaybackSnapshot(from: playerView, state: mappedState) { [weak self] index, time in
                guard let self else { return }
                onStateChange(mappedState, index, time)
                applyPlaybackIfReady()
                if mappedState == .playing {
                    ToneEngine.shared.ensureRunningIfDesired()
                    AudioSessionManager.configureForPlayback()
                }
            }
        }

        func playerView(_ playerView: YTPlayerView, didPlayTime playTime: Float) {
            captureProgressSnapshot(from: playerView, playTime: Double(playTime))
        }

        func playerView(_ playerView: YTPlayerView, receivedError error: YTPlayerError) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onError(self.describe(error: error))
            }
        }

        private func capturePlaybackSnapshot(
            from playerView: YTPlayerView,
            state: YouTubePlayerState,
            completion: @escaping (Int, Double) -> Void
        ) {
            playerView.playlistIndex { [weak self] index, _ in
                guard let self else { return }
                playerView.currentTime { [weak self] time, _ in
                    guard let self else { return }
                    DispatchQueue.main.async {
                        let resolvedIndex = max(0, Int(index))
                        let resolvedTime = max(0, Double(time))
                        switch state {
                        case .playing, .paused:
                            self.lastAppliedIndex = resolvedIndex
                            self.lastAppliedStartTime = resolvedTime
                        case .ended:
                            self.lastAppliedIndex = 0
                            self.lastAppliedStartTime = 0
                        default:
                            break
                        }
                        completion(resolvedIndex, resolvedTime)
                    }
                }
            }
        }

        private func captureProgressSnapshot(from playerView: YTPlayerView, playTime: Double) {
            playerView.duration { [weak self] duration, _ in
                guard let self else { return }
                playerView.playlistIndex { [weak self] index, _ in
                    guard let self else { return }
                    let resolvedIndex = max(0, Int(index))
                    DispatchQueue.main.async {
                        self.lastReportedIndex = resolvedIndex
                        self.onProgress(resolvedIndex, playTime, max(0, duration))
                    }
                }
            }
        }

        private func mapState(_ state: YTPlayerState) -> YouTubePlayerState {
            switch state {
            case .unstarted:
                return .unstarted
            case .ended:
                return .ended
            case .playing:
                return .playing
            case .paused:
                return .paused
            case .buffering:
                return .buffering
            case .cued:
                return .cued
            case .unknown:
                return .unstarted
            @unknown default:
                return .unstarted
            }
        }

        private func describe(error: YTPlayerError) -> String {
            switch error {
            case .invalidParam:
                return "This playlist could not be loaded due to an invalid parameter."
            case .html5Error:
                return "YouTube reported an HTML5 playback error."
            case .videoNotFound:
                return "One of the playlist videos is unavailable."
            case .notEmbeddable:
                return "This playlist contains a video that cannot play in embedded mode."
            case .unknown:
                return "An unknown YouTube player error occurred."
            @unknown default:
                return "An unexpected YouTube player error occurred."
            }
        }

        private static func makePlayerVars(
            startIndex: Int,
            startTime: Double,
            autoplay: Bool
        ) -> [String: Any] {
            [
                "playsinline": 1,
                "controls": 1,
                "rel": 0,
                "modestbranding": 1,
                "iv_load_policy": 3,
                "origin": "https://www.youtube.com",
                "index": startIndex,
                "startSeconds": startTime,
                "autoplay": autoplay ? 1 : 0
            ]
        }
    }
}
