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
    private let nowPlaying: NowPlayingManager
    private var cancellables: Set<AnyCancellable> = []

    init(
        presetStore: PresetStore = .shared,
        settings: SettingsStore = .shared,
        engine: ToneEngine = .shared,
        nowPlaying: NowPlayingManager = .shared
    ) {
        self.presetStore = presetStore
        self.settings = settings
        self.engine = engine
        self.nowPlaying = nowPlaying
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
        configureRemoteCommands()
        updateNowPlaying(isPlaying: false)
    }

    func togglePlayPause() {
        guard let preset = selectedPreset else {
            if let first = presets.first {
                activatePreset(first, mode: outputMode)
            }
            return
        }

        if engine.isRunning {
            engine.pause()
            isPlaying = false
            updateNowPlaying(isPlaying: false)
        } else {
            do {
                try engine.configure(preset: preset, mode: outputMode)
                try engine.start()
                isPlaying = true
                updateNowPlaying(isPlaying: true)
            } catch {
                print("Failed to resume playback: \\(error)")
            }
        }

        settings.lastPresetName = preset.name
    }

    func activatePreset(_ preset: Preset, mode: OutputMode) {
        let isSamePreset = selectedPreset?.name == preset.name
        let modeChanged = outputMode != mode

        outputMode = mode

        if isSamePreset, !modeChanged {
            if engine.isRunning {
                engine.pause()
                isPlaying = false
                updateNowPlaying(isPlaying: false)
            } else {
                do {
                    try engine.configure(preset: preset, mode: mode)
                    try engine.start()
                    isPlaying = true
                    updateNowPlaying(isPlaying: true)
                } catch {
                    print("Failed to resume preset: \\(error)")
                }
            }
            return
        }

        do {
            try engine.configure(preset: preset, mode: mode)
            try engine.start()
            selectedPreset = preset
            isPlaying = true
            settings.lastPresetName = preset.name
            updateNowPlaying(isPlaying: true)
        } catch {
            print("Failed to configure tone engine: \\(error)")
        }
    }

    private func restoreSelectionIfNeeded(from presets: [Preset]) {
        if let name = settings.lastPresetName,
           let restored = presets.first(where: { $0.name == name }) {
            selectedPreset = restored
            do {
                try engine.configure(preset: restored, mode: outputMode)
            } catch {
                print("Failed to restore preset: \\(error)")
            }
            updateNowPlaying(isPlaying: false)
        }
    }

    private func configureRemoteCommands() {
        nowPlaying.configureRemoteCommands(
            onPlay: { [weak self] in
                Task { @MainActor in self?.handleRemotePlay() }
            },
            onPause: { [weak self] in
                Task { @MainActor in self?.handleRemotePause() }
            }
        )
    }

    private func handleRemotePlay() {
        guard let preset = selectedPreset else { return }
        do {
            try engine.configure(preset: preset, mode: outputMode)
            try engine.start()
            isPlaying = true
            updateNowPlaying(isPlaying: true)
        } catch {
            print("Remote play failed: \\(error)")
        }
    }

    private func handleRemotePause() {
        guard engine.isRunning else { return }
        engine.pause()
        isPlaying = false
        updateNowPlaying(isPlaying: false)
    }

    private func updateNowPlaying(isPlaying: Bool) {
        nowPlaying.update(presetName: selectedPreset?.name, isPlaying: isPlaying)
    }
}
