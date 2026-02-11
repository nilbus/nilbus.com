import Foundation
import MediaPlayer
import UIKit

final class NowPlayingManager {
    static let shared = NowPlayingManager()

    private static var nowPlayingLogoName: String {
        #if KIDS
        return "logo_kids"
        #else
        return "ba_logo"
        #endif
    }

    private var playHandler: (() -> Void)?
    private var pauseHandler: (() -> Void)?
    private var skipForwardHandler: (() -> Void)?
    private var skipBackwardHandler: (() -> Void)?
    private var seekHandler: ((TimeInterval) -> Void)?

    private init() {}

    func configureRemoteCommands(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void
    ) {
        playHandler = onPlay
        pauseHandler = onPause

        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.playHandler?()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pauseHandler?()
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .noSuchContent }
            if MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 1.0 {
                self.pauseHandler?()
            } else {
                self.playHandler?()
            }
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.skipForwardHandler?()
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.skipBackwardHandler?()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard
                let event = event as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }
            self?.seekHandler?(event.positionTime)
            return .success
        }
    }

    func updateHandlers(
        onSkipForward: @escaping () -> Void,
        onSkipBackward: @escaping () -> Void,
        onSeek: @escaping (TimeInterval) -> Void
    ) {
        skipForwardHandler = onSkipForward
        skipBackwardHandler = onSkipBackward
        seekHandler = onSeek
    }

    func update(
        presetName: String?,
        playlistTitle: String?,
        trackTitle: String?,
        trackDuration: TimeInterval?,
        trackPosition: TimeInterval,
        isPlaying: Bool
    ) {
        var info: [String: Any] = [
            MPNowPlayingInfoPropertyIsLiveStream: false
        ]

        let title = trackTitle ?? "Brain Tones"
        let artist = presetName ?? "Brain Tones"
        let album = playlistTitle ?? "Brain Tones"

        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist
        info[MPMediaItemPropertyAlbumTitle] = album

        if let duration = trackDuration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        if let artworkImage = UIImage(named: Self.nowPlayingLogoName) {
            let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in
                artworkImage
            }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = trackPosition
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
