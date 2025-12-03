import AVFoundation

final class ToneEngine {
    static let shared = ToneEngine()

    private let engine = AVAudioEngine()
    private var layerNodes: [ToneLayerNode] = []
    private var shouldBeRunning = false
    private var shouldResumeAfterInterruption = false
    private var shouldResumeAfterSilenceHint = false

    private(set) var currentPreset: Preset?
    private(set) var currentMode: OutputMode = .headphones

    var isRunning: Bool {
        engine.isRunning
    }

    private init() {
        engine.mainMixerNode.outputVolume = 1.0
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSilenceSecondaryAudioHint(_:)),
            name: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: nil
        )
    }

    func configure(preset: Preset, mode: OutputMode) throws {
        currentPreset = preset
        currentMode = mode
        try rebuildGraph(with: preset, mode: mode, resumePlayback: engine.isRunning)
    }

    func start() throws {
        AudioSessionManager.configureForPlayback()
        if !engine.isRunning {
            try engine.start()
        }
        shouldBeRunning = true
    }

    func pause() {
        guard engine.isRunning else { return }
        engine.pause()
        shouldBeRunning = false
    }

    func stop() {
        engine.stop()
        shouldBeRunning = false
    }

    private func rebuildGraph(with preset: Preset, mode: OutputMode, resumePlayback: Bool) throws {
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let parameters = preset.parameters(for: mode)

        engine.stop()
        detachAllNodes()

        layerNodes = parameters.compactMap { ToneLayerNode(parameters: $0, sampleRate: sampleRate) }
        for node in layerNodes {
            node.attach(to: engine)
        }

        engine.prepare()

        if resumePlayback {
            AudioSessionManager.configureForPlayback()
            try engine.start()
            shouldBeRunning = true
        } else {
            shouldBeRunning = false
        }
    }

    private func detachAllNodes() {
        for node in layerNodes {
            node.detach(from: engine)
        }
        layerNodes.removeAll()
    }

    func ensureRunningIfDesired() {
        guard shouldBeRunning else { return }
        if !engine.isRunning {
            AudioSessionManager.configureForPlayback()
            do {
                try engine.start()
            } catch {
                print("Failed to resume tone engine: \\(error)")
            }
        }
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            shouldResumeAfterInterruption = shouldBeRunning
        case .ended:
            if shouldResumeAfterInterruption {
                shouldResumeAfterInterruption = false
                DispatchQueue.main.async { [weak self] in
                    self?.ensureRunningIfDesired()
                }
            }
        @unknown default:
            break
        }
    }

    @objc private func handleSilenceSecondaryAudioHint(_ notification: Notification) {
        guard let typeValue = notification.userInfo?[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
              let type = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: typeValue) else { return }

        switch type {
        case .begin:
            shouldResumeAfterSilenceHint = shouldBeRunning
        case .end:
            if shouldResumeAfterSilenceHint {
                shouldResumeAfterSilenceHint = false
                DispatchQueue.main.async { [weak self] in
                    self?.ensureRunningIfDesired()
                }
            }
        @unknown default:
            break
        }
    }
}
