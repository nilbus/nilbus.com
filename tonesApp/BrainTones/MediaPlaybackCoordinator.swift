import Foundation

@MainActor
final class MediaPlaybackCoordinator {
    static let shared = MediaPlaybackCoordinator()

    private let nowPlayingManager: NowPlayingManager

    private var tonePlayHandler: (() -> Void)?
    private var tonePauseHandler: (() -> Void)?
    private var toneSkipForwardHandler: (() -> Bool)?
    private var toneSkipBackwardHandler: (() -> Bool)?

    private var musicPlayHandler: (() -> Void)?
    private var musicPauseHandler: (() -> Void)?
    private var musicSkipForwardHandler: (() -> Void)?
    private var musicSkipBackwardHandler: (() -> Void)?
    private var musicSeekHandler: ((TimeInterval) -> Void)?

    private(set) var isTonesPlaying = false
    private(set) var isMusicPlaying = false

    private var desiredTonesPlaying = false
    private var desiredMusicPlaying = false

    private var pendingToneIntent: Bool?
    private var pendingMusicIntent: Bool?

    private var currentPresetName: String?
    private var currentPlaylistTitle: String?
    private var currentTrackTitle: String?
    private var currentTrackDuration: TimeInterval?
    private var currentTrackPosition: TimeInterval = 0

    private init(nowPlayingManager: NowPlayingManager = .shared) {
        self.nowPlayingManager = nowPlayingManager
        configureRemoteCommands()
    }

    // MARK: - Registration

    func registerToneControls(play: @escaping () -> Void, pause: @escaping () -> Void) {
        tonePlayHandler = play
        tonePauseHandler = pause
    }

    func registerToneSeriesControls(
        skipForward: @escaping () -> Bool,
        skipBackward: @escaping () -> Bool
    ) {
        toneSkipForwardHandler = skipForward
        toneSkipBackwardHandler = skipBackward
    }

    func registerMusicControls(
        play: @escaping () -> Void,
        pause: @escaping () -> Void,
        skipForward: @escaping () -> Void,
        skipBackward: @escaping () -> Void,
        seek: @escaping (TimeInterval) -> Void
    ) {
        musicPlayHandler = play
        musicPauseHandler = pause
        musicSkipForwardHandler = skipForward
        musicSkipBackwardHandler = skipBackward
        musicSeekHandler = seek
        nowPlayingManager.updateHandlers(
            onSkipForward: { [weak self] in
                Task { @MainActor in self?.skipForward() }
            },
            onSkipBackward: { [weak self] in
                Task { @MainActor in self?.skipBackward() }
            },
            onSeek: { [weak self] position in
                Task { @MainActor in self?.musicSeekHandler?(position) }
            }
        )
    }

    // MARK: - Desired State

    func setTonesDesired(_ desired: Bool) {
        guard pendingToneIntent == nil else { return }
        desiredTonesPlaying = desired
    }

    func setMusicDesired(_ desired: Bool) {
        guard pendingMusicIntent == nil else { return }
        desiredMusicPlaying = desired
    }

    func requestTonePlayback() {
        setTonesDesired(true)
        if !isTonesPlaying {
            tonePlayHandler?()
        }
    }

    func requestMusicPlayback() {
        setMusicDesired(true)
        if !isMusicPlaying {
            musicPlayHandler?()
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

    func musicStateDidChange(
        isPlaying: Bool,
        playlistTitle: String?,
        trackTitle: String?,
        position: TimeInterval,
        duration: TimeInterval?
    ) {
        if let pending = pendingMusicIntent {
            desiredMusicPlaying = pending
            pendingMusicIntent = nil
        }

        isMusicPlaying = isPlaying
        if let playlistTitle {
            currentPlaylistTitle = playlistTitle
        }
        if let trackTitle {
            currentTrackTitle = trackTitle
        }
        currentTrackPosition = position
        currentTrackDuration = duration

        if isPlaying {
            AudioSessionManager.configureForPlayback()
            ToneEngine.shared.ensureRunningIfDesired()
        }

        updateNowPlaying()
    }

    // MARK: - Global Controls

    func playAll(rememberIntent: Bool = false) {
        // If neither tones nor music have been explicitly desired yet (e.g., first play after app launch),
        // start both by default. This implements the PRD requirement: "Play: Resume the last played
        // tone preset and last played track (at its saved playback position). Both tones and music start together."
        let shouldPlayBothByDefault = !desiredTonesPlaying && !desiredMusicPlaying

        if shouldPlayBothByDefault || desiredTonesPlaying {
            desiredTonesPlaying = true
            tonePlayHandler?()
        }

        if shouldPlayBothByDefault || desiredMusicPlaying {
            desiredMusicPlaying = true
            musicPlayHandler?()
        }
    }

    func pauseAll(rememberIntent: Bool = false) {
        if rememberIntent {
            pendingToneIntent = desiredTonesPlaying
            pendingMusicIntent = desiredMusicPlaying
        }

        tonePauseHandler?()
        musicPauseHandler?()
    }

    func togglePlayPause() {
        if isTonesPlaying || isMusicPlaying {
            pauseAll(rememberIntent: true)
        } else {
            playAll(rememberIntent: true)
        }
    }

    func skipForward() {
        if toneSkipForwardHandler?() == true { return }
        musicSkipForwardHandler?()
    }

    func skipBackward() {
        if toneSkipBackwardHandler?() == true { return }
        musicSkipBackwardHandler?()
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
        nowPlayingManager.update(
            presetName: currentPresetName,
            playlistTitle: currentPlaylistTitle,
            trackTitle: currentTrackTitle,
            trackDuration: currentTrackDuration,
            trackPosition: currentTrackPosition,
            isPlaying: isTonesPlaying || isMusicPlaying
        )
    }

#if DEBUG
    func resetForTesting() {
        tonePlayHandler = nil
        tonePauseHandler = nil
        toneSkipForwardHandler = nil
        toneSkipBackwardHandler = nil
        musicPlayHandler = nil
        musicPauseHandler = nil
        musicSkipForwardHandler = nil
        musicSkipBackwardHandler = nil
        musicSeekHandler = nil
        isTonesPlaying = false
        isMusicPlaying = false
        desiredTonesPlaying = false
        desiredMusicPlaying = false
        pendingToneIntent = nil
        pendingMusicIntent = nil
        currentPresetName = nil
        currentPlaylistTitle = nil
        currentTrackTitle = nil
        currentTrackDuration = nil
        currentTrackPosition = 0
    }
#endif
}
