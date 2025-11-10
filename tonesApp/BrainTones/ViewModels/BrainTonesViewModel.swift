import Foundation
import Combine

@MainActor
final class BrainTonesViewModel: ObservableObject {
    @Published private(set) var presets: [Preset] = []
    @Published var selectedPreset: Preset?
    @Published var isPlaying: Bool = false
    @Published var outputMode: OutputMode {
        didSet {
            settings.outputMode = outputMode
        }
    }

    private let presetStore: PresetStore
    private let settings: SettingsStore
    private let engine: ToneEngine
    private let playbackCoordinator: MediaPlaybackCoordinator
    private var cancellables: Set<AnyCancellable> = []

    init(
        presetStore: PresetStore = .shared,
        settings: SettingsStore = .shared,
        engine: ToneEngine = .shared,
        playbackCoordinator: MediaPlaybackCoordinator? = nil
    ) {
        self.presetStore = presetStore
        self.settings = settings
        self.engine = engine
        self.playbackCoordinator = playbackCoordinator ?? MediaPlaybackCoordinator.shared
        outputMode = settings.outputMode

        presetStore.$presets
            .receive(on: DispatchQueue.main)
            .sink { [weak self] presets in
                self?.presets = presets
                self?.restoreSelectionIfNeeded(from: presets)
            }
            .store(in: &cancellables)

        presets = presetStore.presets
        restoreSelectionIfNeeded(from: presets)
        registerWithCoordinator()
        self.playbackCoordinator.tonesStateDidChange(isPlaying: isPlaying, presetName: selectedPreset?.name)
    }

    func togglePlayPause() {
        guard let preset = selectedPreset else {
            guard let first = presets.first else { return }
            playbackCoordinator.setTonesDesired(true)
            activatePreset(first, mode: outputMode)
            return
        }

        if engine.isRunning {
            playbackCoordinator.setTonesDesired(false)
            pausePlayback()
        } else {
            playbackCoordinator.setTonesDesired(true)
            startPlayback(with: preset, mode: outputMode, updateSelection: false)
        }

        settings.lastPresetName = preset.name
    }

    func activatePreset(_ preset: Preset, mode: OutputMode) {
        let isSamePreset = selectedPreset?.name == preset.name
        let modeChanged = outputMode != mode

        outputMode = mode

        if isSamePreset, !modeChanged {
            if engine.isRunning {
                playbackCoordinator.setTonesDesired(false)
                pausePlayback()
            } else {
                playbackCoordinator.setTonesDesired(true)
                startPlayback(with: preset, mode: mode, updateSelection: false)
            }
            return
        }

        playbackCoordinator.setTonesDesired(true)
        startPlayback(with: preset, mode: mode, updateSelection: true)
    }

    private func startPlayback(with preset: Preset, mode: OutputMode, updateSelection: Bool) {
        do {
            try engine.configure(preset: preset, mode: mode)
            try engine.start()
            if updateSelection {
                selectedPreset = preset
            }
            isPlaying = true
            settings.lastPresetName = preset.name
            playbackCoordinator.tonesStateDidChange(isPlaying: true, presetName: preset.name)
        } catch {
            print("Failed to start preset: \(error)")
        }
    }

    private func pausePlayback() {
        guard engine.isRunning else {
            playbackCoordinator.tonesStateDidChange(isPlaying: false, presetName: selectedPreset?.name)
            return
        }
        engine.pause()
        isPlaying = false
        playbackCoordinator.tonesStateDidChange(isPlaying: false, presetName: selectedPreset?.name)
    }

    private func restoreSelectionIfNeeded(from presets: [Preset]) {
        guard let name = settings.lastPresetName,
              let restored = presets.first(where: { $0.name == name }) else { return }

        selectedPreset = restored
        do {
            try engine.configure(preset: restored, mode: outputMode)
        } catch {
            print("Failed to restore preset: \(error)")
        }
        playbackCoordinator.tonesStateDidChange(isPlaying: false, presetName: restored.name)
    }

    private func registerWithCoordinator() {
        playbackCoordinator.registerToneControls(
            play: { [weak self] in Task { @MainActor in self?.handleCoordinatorPlay() } },
            pause: { [weak self] in Task { @MainActor in self?.handleCoordinatorPause() } }
        )
    }

    private func handleCoordinatorPlay() {
        if let preset = selectedPreset {
            startPlayback(with: preset, mode: outputMode, updateSelection: false)
            return
        }

        if let lastName = settings.lastPresetName,
           let restored = presets.first(where: { $0.name == lastName }) {
            startPlayback(with: restored, mode: outputMode, updateSelection: true)
            return
        }

        if let first = presets.first {
            startPlayback(with: first, mode: outputMode, updateSelection: true)
        }
    }

    private func handleCoordinatorPause() {
        pausePlayback()
    }
}
