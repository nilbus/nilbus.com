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
    /// Use bundle ID so the correct preset file is chosen at runtime (Kids bundle
    /// only contains presets_kids.json). More reliable than compile-time KIDS flag.
    static var presetsFileName: String {
        if bundleIdentifier == "com.nilbus.BrainTonesKids" {
            return "presets_kids"
        }
        return "presets"
    }

    private static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? ""
    }

    func loadPresets() {
        guard let url = bundle.url(forResource: Self.presetsFileName, withExtension: "json") else {
            print("Missing \(Self.presetsFileName).json in bundle.")
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
