import Foundation
import MediaPlayer
import UIKit

final class NowPlayingManager {
    static let shared = NowPlayingManager()

    private var playHandler: (() -> Void)?
    private var pauseHandler: (() -> Void)?

    private init() {}

    func configureRemoteCommands(onPlay: @escaping () -> Void, onPause: @escaping () -> Void) {
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
    }

    func update(presetName: String?, isPlaying: Bool) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: presetName ?? "Brain Tones",
            MPMediaItemPropertyArtist: "Brainaural",
            MPMediaItemPropertyAlbumTitle: "Brainwave Presets",
            MPNowPlayingInfoPropertyIsLiveStream: true
        ]

        if let artworkImage = UIImage(named: "ba_logo") {
            let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in
                artworkImage
            }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
