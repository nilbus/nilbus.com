import AVFoundation

final class ToneEngine {
    static let shared = ToneEngine()

    private let engine = AVAudioEngine()
    private var layerNodes: [ToneLayerNode] = []

    private(set) var currentPreset: Preset?
    private(set) var currentMode: OutputMode = .headphones

    var isRunning: Bool {
        engine.isRunning
    }

    private init() {
        engine.mainMixerNode.outputVolume = 1.0
    }

    func configure(preset: Preset, mode: OutputMode) throws {
        currentPreset = preset
        currentMode = mode
        try rebuildGraph(with: preset, mode: mode, resumePlayback: engine.isRunning)
    }

    func start() throws {
        if !engine.isRunning {
            try engine.start()
        }
    }

    func pause() {
        guard engine.isRunning else { return }
        engine.pause()
    }

    func stop() {
        engine.stop()
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
            try engine.start()
        }
    }

    private func detachAllNodes() {
        for node in layerNodes {
            node.detach(from: engine)
        }
        layerNodes.removeAll()
    }
}
