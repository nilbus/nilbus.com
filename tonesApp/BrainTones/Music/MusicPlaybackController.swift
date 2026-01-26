import AVFoundation
import Combine
import Foundation

struct MusicPlayerRuntimeState {
    var playlist: AudioPlaylist?
    var trackIndex: Int
    var track: AudioTrack?
    var isPlaying: Bool
    var position: TimeInterval
    var duration: TimeInterval?
    var downloadProgress: Double
    var downloadingTrackId: String?
    var isBuffering: Bool
    var errorMessage: String?

    static let empty = MusicPlayerRuntimeState(
        playlist: nil,
        trackIndex: 0,
        track: nil,
        isPlaying: false,
        position: 0,
        duration: nil,
        downloadProgress: 0,
        downloadingTrackId: nil,
        isBuffering: false,
        errorMessage: nil
    )
}

@MainActor
protocol MusicPlaybackControlling: AnyObject {
    var state: MusicPlayerRuntimeState { get }
    var statePublisher: AnyPublisher<MusicPlayerRuntimeState, Never> { get }

    func configure(with playlist: AudioPlaylist, startIndex: Int, startTime: TimeInterval, autoplay: Bool)
    func play()
    func pause()
    func togglePlayback()
    func seek(to time: TimeInterval)
    func skipForward()
    func skipBackward()
    func selectTrack(at index: Int, startTime: TimeInterval, autoplay: Bool)
}

@MainActor
final class MusicPlaybackController: ObservableObject, MusicPlaybackControlling {
    @Published private(set) var state: MusicPlayerRuntimeState = .empty

    private let player: AVPlayer
    private let downloadManager: TrackDownloadManager
    private let playbackCoordinator: MediaPlaybackCoordinator

    private var timeObserverToken: Any?
    private var endObserver: NSObjectProtocol?
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var currentItemStatusObserver: NSKeyValueObservation?
    private var currentPreparationTask: Task<Void, Never>?
    private var activeDownloadProgressToken: TrackDownloadProgressToken?
    private var activeDownloadTrackId: String?
    var statePublisher: AnyPublisher<MusicPlayerRuntimeState, Never> {
        $state.eraseToAnyPublisher()
    }

    init(
        player: AVPlayer = AVPlayer(),
        downloadManager: TrackDownloadManager = TrackDownloadManager(),
        playbackCoordinator: MediaPlaybackCoordinator? = nil
    ) {
        self.player = player
        self.downloadManager = downloadManager
        self.playbackCoordinator = playbackCoordinator ?? MediaPlaybackCoordinator.shared
        configureObservers()
    }

    deinit {
        let token = timeObserverToken
        let observer = endObserver
        let task = currentPreparationTask
        let player = self.player
        Task { @MainActor in
            if let token {
                player.removeTimeObserver(token)
            }
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
            self.timeControlStatusObserver?.invalidate()
            self.currentItemStatusObserver?.invalidate()
            task?.cancel()
        }
    }

    func configure(
        with playlist: AudioPlaylist,
        startIndex: Int,
        startTime: TimeInterval,
        autoplay: Bool
    ) {
        let safeIndex = min(max(startIndex, 0), playlist.tracks.count - 1)
        state = MusicPlayerRuntimeState(
            playlist: playlist,
            trackIndex: safeIndex,
            track: playlist.tracks[safeIndex],
            isPlaying: autoplay,
            position: startTime,
            duration: nil,
            downloadProgress: 0,
            downloadingTrackId: nil,
            isBuffering: false,
            errorMessage: nil
        )

        playbackCoordinator.setMusicDesired(autoplay)
        prepareCurrentTrack(seekTime: startTime, autoplay: autoplay)
    }

    func play() {
        guard state.track != nil else { return }
        player.play()
        playbackCoordinator.setMusicDesired(true)
        updateState(isPlaying: true)
    }

    func pause() {
        player.pause()
        playbackCoordinator.setMusicDesired(false)
        updateState(isPlaying: false)
    }

    func togglePlayback() {
        if state.isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to time: TimeInterval) {
        guard time.isFinite else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        updateState(position: time)
    }

    func skipForward() {
        guard let playlist = state.playlist else { return }
        let nextIndex = state.trackIndex + 1
        guard nextIndex < playlist.tracks.count else {
            stopPlayback()
            return
        }
        updateForTrackChange(index: nextIndex, startTime: 0, autoplay: state.isPlaying)
    }

    func skipBackward() {
        guard let playlist = state.playlist else { return }
        let shouldRestart = state.position > 5
        if shouldRestart {
            seek(to: 0)
            return
        }
        let prevIndex = max(state.trackIndex - 1, 0)
        updateForTrackChange(index: prevIndex, startTime: 0, autoplay: state.isPlaying)
    }

    func selectTrack(at index: Int, startTime: TimeInterval, autoplay: Bool) {
        guard let playlist = state.playlist else { return }
        guard playlist.tracks.indices.contains(index) else { return }
        updateForTrackChange(index: index, startTime: startTime, autoplay: autoplay)
    }

    func stopPlayback() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        updateState(isPlaying: false, position: 0)
        playbackCoordinator.setMusicDesired(false)
    }
}

// MARK: - Private Helpers

private extension MusicPlaybackController {
    func configureObservers() {
        let interval = CMTime(seconds: 1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite {
                self.updateState(position: seconds)
            }
        }

        timeControlStatusObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            guard let self else { return }
            let buffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            self.updateState(isBuffering: buffering, notifyCoordinator: false)
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.handleTrackEnded()
        }
    }

    func removeObservers() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        timeControlStatusObserver?.invalidate()
        timeControlStatusObserver = nil
        currentItemStatusObserver?.invalidate()
        currentItemStatusObserver = nil
    }

    func clearCurrentDownloadProgressHandler() {
        guard let trackId = activeDownloadTrackId, let token = activeDownloadProgressToken else { return }
        activeDownloadTrackId = nil
        activeDownloadProgressToken = nil
        Task {
            await downloadManager.removeProgressHandler(for: trackId, token: token)
        }
    }

    func prepareCurrentTrack(seekTime: TimeInterval, autoplay: Bool) {
        currentPreparationTask?.cancel()
        guard let playlist = state.playlist else { return }
        let track = playlist.tracks[state.trackIndex]
        let trackId = track.id

        currentPreparationTask = Task { [weak self] in
            guard let self else { return }

            await self.cancelActiveDownloadIfNeeded(for: trackId)

            let localURL = await self.downloadManager.localURL(for: trackId)
            let playableURL = localURL ?? track.remoteURL
            let needsDownload = localURL == nil

            await MainActor.run {
                guard self.state.track?.id == trackId else { return }
                if needsDownload {
                    self.updateState(
                        downloadProgress: 0,
                        downloadingTrackId: .some(trackId),
                        errorMessage: .some(nil),
                        notifyCoordinator: false
                    )
                } else {
                    self.updateState(
                        downloadProgress: 0,
                        downloadingTrackId: .some(nil),
                        errorMessage: .some(nil),
                        notifyCoordinator: false
                    )
                }
                self.load(url: playableURL, seekTime: seekTime, autoplay: autoplay)
            }

            if needsDownload {
                await self.startDownload(for: track, switchToLocal: true)
            }

            await self.prefetchNextTrack(afterTrackId: trackId)
        }
    }

    func load(url: URL, seekTime: TimeInterval, autoplay: Bool) {
        let item = AVPlayerItem(url: url)
        currentItemStatusObserver?.invalidate()
        currentItemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            switch item.status {
            case .readyToPlay:
                Task { @MainActor in
                    self.updateState(duration: self.durationForCurrentItem(), notifyCoordinator: true)
                }
            case .failed:
                let error = item.error?.localizedDescription ?? "Unknown error"
                print("Playback item failed: \(error)")
                Task { @MainActor in
                    self.player.pause()
                    self.updateState(
                        isPlaying: false,
                        errorMessage: .some("Playback failed. Please try another track."),
                        notifyCoordinator: true
                    )
                }
            default:
                break
            }
        }

        player.replaceCurrentItem(with: item)

        if seekTime > 0 {
            let cmTime = CMTime(seconds: seekTime, preferredTimescale: 600)
            player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        if autoplay {
            player.play()
        }

        updateState(
            isPlaying: autoplay,
            position: seekTime,
            duration: durationForCurrentItem()
        )
    }

    func updateForTrackChange(index: Int, startTime: TimeInterval, autoplay: Bool) {
        guard let playlist = state.playlist else { return }
        state = MusicPlayerRuntimeState(
            playlist: playlist,
            trackIndex: index,
            track: playlist.tracks[index],
            isPlaying: autoplay,
            position: startTime,
            duration: nil,
            downloadProgress: 0,
            downloadingTrackId: nil,
            isBuffering: false,
            errorMessage: nil
        )

        playbackCoordinator.setMusicDesired(autoplay)
        prepareCurrentTrack(seekTime: startTime, autoplay: autoplay)
    }

    func prefetchNextTrack(afterTrackId trackId: String) async {
        guard
            let playlist = state.playlist,
            state.track?.id == trackId,
            state.trackIndex + 1 < playlist.tracks.count,
            activeDownloadTrackId == nil
        else { return }

        let nextTrack = playlist.tracks[state.trackIndex + 1]
        if await downloadManager.localURL(for: nextTrack.id) != nil {
            return
        }

        await startDownload(for: nextTrack, switchToLocal: false)
    }

    func cancelActiveDownloadIfNeeded(for trackId: String) async {
        guard let activeId = activeDownloadTrackId, activeId != trackId else { return }
        clearCurrentDownloadProgressHandler()
        await downloadManager.cancelDownload(for: activeId)
        await MainActor.run {
            self.updateState(
                downloadProgress: 0,
                downloadingTrackId: .some(nil),
                notifyCoordinator: false
            )
        }
    }

    func startDownload(for track: AudioTrack, switchToLocal: Bool) async {
        let trackId = track.id
        let (downloadTask, token) = await downloadManager.ensureDownload(
            for: track,
            progress: { [weak self] progress in
                guard let self else { return }
                Task { @MainActor in
                    self.updateState(
                        downloadProgress: progress,
                        downloadingTrackId: .some(trackId),
                        notifyCoordinator: false
                    )
                }
            }
        )

        await MainActor.run {
            self.activeDownloadTrackId = trackId
            self.activeDownloadProgressToken = token
            self.updateState(
                downloadProgress: 0,
                downloadingTrackId: .some(trackId),
                errorMessage: .some(nil),
                notifyCoordinator: false
            )
        }

        do {
            let localURL = try await downloadTask.value
            await MainActor.run {
                if self.activeDownloadTrackId == trackId {
                    self.activeDownloadTrackId = nil
                    self.activeDownloadProgressToken = nil
                }
                self.updateState(
                    downloadProgress: 0,
                    downloadingTrackId: .some(nil),
                    notifyCoordinator: false
                )
                if switchToLocal {
                    self.switchToDownloadedFileIfNeeded(trackId: trackId, localURL: localURL)
                }
            }
        } catch {
            await MainActor.run {
                if self.activeDownloadTrackId == trackId {
                    self.activeDownloadTrackId = nil
                    self.activeDownloadProgressToken = nil
                }
                if error is CancellationError {
                    self.updateState(
                        downloadProgress: 0,
                        downloadingTrackId: .some(nil),
                        notifyCoordinator: false
                    )
                    return
                }
                self.updateState(
                    downloadProgress: 0,
                    downloadingTrackId: .some(nil),
                    errorMessage: .some("Download failed. We'll keep streaming the track."),
                    notifyCoordinator: false
                )
            }
        }
    }

    func switchToDownloadedFileIfNeeded(trackId: String, localURL: URL) {
        guard state.track?.id == trackId else { return }
        guard let asset = player.currentItem?.asset as? AVURLAsset,
              !asset.url.isFileURL else { return }
        let currentTime = player.currentTime().seconds
        let seekTime = currentTime.isFinite ? currentTime : state.position
        let shouldPlay = state.isPlaying
        load(url: localURL, seekTime: seekTime, autoplay: shouldPlay)
    }

    func handleTrackEnded() {
        guard let playlist = state.playlist else {
            stopPlayback()
            return
        }

        let nextIndex = state.trackIndex + 1
        if nextIndex < playlist.tracks.count {
            updateForTrackChange(index: nextIndex, startTime: 0, autoplay: true)
        } else {
            stopPlayback()
        }
    }

    func durationForCurrentItem() -> TimeInterval? {
        guard let duration = player.currentItem?.asset.duration else { return nil }
        let seconds = CMTimeGetSeconds(duration)
        return seconds.isFinite ? seconds : nil
    }

    func updateState(
        isPlaying: Bool? = nil,
        position: TimeInterval? = nil,
        duration: TimeInterval? = nil,
        downloadProgress: Double? = nil,
        downloadingTrackId: String?? = nil,
        isBuffering: Bool? = nil,
        errorMessage: String?? = nil,
        notifyCoordinator: Bool = true
    ) {
        var newState = state
        if let isPlaying {
            newState.isPlaying = isPlaying
        }
        if let position {
            newState.position = position
        }
        if let duration {
            newState.duration = duration
        }
        if let downloadProgress {
            newState.downloadProgress = downloadProgress
        }
        if let downloadingTrackId {
            newState.downloadingTrackId = downloadingTrackId
        }
        if let isBuffering {
            newState.isBuffering = isBuffering
        }
        if let errorMessage {
            newState.errorMessage = errorMessage
        }
        state = newState

        guard notifyCoordinator else { return }
        playbackCoordinator.musicStateDidChange(
            isPlaying: state.isPlaying,
            playlistTitle: state.playlist?.title,
            trackTitle: state.track?.title,
            position: state.position,
            duration: state.duration
        )
    }
}
