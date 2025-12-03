import Foundation
import Combine

final class PresetStore: ObservableObject {
    static let shared = PresetStore()

    @Published private(set) var presets: [Preset] = []
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        loadPresets()
    }

    func reload() {
        loadPresets()
    }

    func preset(named name: String) -> Preset? {
        presets.first { $0.name == name }
    }
}

private extension PresetStore {
    func loadPresets() {
        guard let url = bundle.url(forResource: "presets", withExtension: "json") else {
            print("Missing presets.json in bundle.")
            presets = []
            return
        }

        do {
            let library = try PresetLibrary(jsonURL: url)
            presets = library.presets
        } catch {
            print("Failed to load presets: \\(error)")
            presets = []
        }
    }
}
