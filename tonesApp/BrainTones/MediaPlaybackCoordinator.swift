import Foundation
@MainActor
final class MediaPlaybackCoordinator {
    static let shared = MediaPlaybackCoordinator()

    private let nowPlayingManager: NowPlayingManager
    private var tonePlayHandler: (() -> Void)?
    private var tonePauseHandler: (() -> Void)?
    private var youtubePlayHandler: (() -> Void)?
    private var youtubePauseHandler: (() -> Void)?

    private(set) var isTonesPlaying = false
    private(set) var isYouTubePlaying = false

    private var desiredTonesPlaying = false
    private var desiredYouTubePlaying = false

    private var pendingToneIntent: Bool?
    private var pendingYouTubeIntent: Bool?

    private var currentPresetName: String?
    private var currentPlaylistTitle: String?

    private init(nowPlayingManager: NowPlayingManager = .shared) {
        self.nowPlayingManager = nowPlayingManager
        configureRemoteCommands()
    }

    // MARK: - Registration

    func registerToneControls(play: @escaping () -> Void, pause: @escaping () -> Void) {
        tonePlayHandler = play
        tonePauseHandler = pause
    }

    func registerYouTubeControls(play: @escaping () -> Void, pause: @escaping () -> Void) {
        youtubePlayHandler = play
        youtubePauseHandler = pause
    }

    func setTonesDesired(_ desired: Bool) {
        if pendingToneIntent != nil {
            pendingToneIntent = desired
        } else {
            desiredTonesPlaying = desired
        }
    }

    func setYouTubeDesired(_ desired: Bool) {
        if pendingYouTubeIntent != nil {
            pendingYouTubeIntent = desired
        } else {
            desiredYouTubePlaying = desired
        }
    }

    // MARK: - State Updates

    func tonesStateDidChange(isPlaying: Bool, presetName: String?) {
        if let pending = pendingToneIntent {
            desiredTonesPlaying = pending
            pendingToneIntent = nil
        }

        isTonesPlaying = isPlaying
        if let presetName {
            currentPresetName = presetName
        }

        if isPlaying {
            AudioSessionManager.configureForPlayback()
        }

        updateNowPlaying()
    }

    func youtubeStateDidChange(
        isPlaying: Bool,
        playlistTitle: String?,
        index: Int,
        time: Double
    ) {
        if let pending = pendingYouTubeIntent {
            desiredYouTubePlaying = pending
            pendingYouTubeIntent = nil
        }

        isYouTubePlaying = isPlaying
        if let playlistTitle {
            currentPlaylistTitle = playlistTitle
        }

        if isPlaying {
            AudioSessionManager.configureForPlayback()
            ToneEngine.shared.ensureRunningIfDesired()
        }

        updateNowPlaying()
    }

    // MARK: - Global Controls

    func playAll(rememberIntent: Bool = false) {
        if rememberIntent {
            // Use previously stored intents; nothing to change here because setTonesDesired/setYouTubeDesired should already hold them
        }
        if desiredTonesPlaying {
            tonePlayHandler?()
        }
        if desiredYouTubePlaying {
            youtubePlayHandler?()
        }
    }

    func pauseAll(rememberIntent: Bool = false) {
        if rememberIntent {
            pendingToneIntent = desiredTonesPlaying
            pendingYouTubeIntent = desiredYouTubePlaying
        }
        tonePauseHandler?()
        youtubePauseHandler?()
    }

    func togglePlayPause() {
        if isTonesPlaying || isYouTubePlaying {
            pauseAll(rememberIntent: true)
        } else {
            playAll(rememberIntent: true)
        }
    }

    // MARK: - Remote Handling

    private func configureRemoteCommands() {
        nowPlayingManager.configureRemoteCommands(
            onPlay: { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.playAll(rememberIntent: true)
                }
            },
            onPause: { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.pauseAll(rememberIntent: true)
                }
            }
        )
    }

    // MARK: - Metadata

    private func updateNowPlaying() {
        let title: String?

        if isTonesPlaying || desiredTonesPlaying {
            title = currentPresetName ?? "Brain Tones"
        } else if isYouTubePlaying || desiredYouTubePlaying {
            title = currentPlaylistTitle ?? currentPresetName ?? "YouTube Playlist"
        } else {
            title = currentPresetName ?? currentPlaylistTitle
        }

        nowPlayingManager.update(presetName: title, isPlaying: isTonesPlaying || isYouTubePlaying)
    }

#if DEBUG
    func resetForTesting() {
        tonePlayHandler = nil
        tonePauseHandler = nil
        youtubePlayHandler = nil
        youtubePauseHandler = nil
        isTonesPlaying = false
        isYouTubePlaying = false
        desiredTonesPlaying = false
        desiredYouTubePlaying = false
        pendingToneIntent = nil
        pendingYouTubeIntent = nil
        currentPresetName = nil
        currentPlaylistTitle = nil
    }
#endif
}
