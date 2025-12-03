import XCTest
@testable import BrainTones

final class PresetLibraryTests: XCTestCase {
    private var bundle: Bundle {
        Bundle(for: Self.self)
    }

    func testPresetDecodingProducesExpectedCount() throws {
        let url = try XCTUnwrap(bundle.url(forResource: "presets", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let presets = try JSONDecoder().decode([Preset].self, from: data)
        XCTAssertGreaterThan(presets.count, 0, "Expected bundled presets to decode at least one entry.")
    }

    func testParametersVaryBetweenOutputModes() throws {
        let store = PresetStore(bundle: bundle)
        let preset = try XCTUnwrap(store.presets.first)

        let headphoneParams = preset.parameters(for: .headphones)
        let speakerParams = preset.parameters(for: .speakers)

        XCTAssertEqual(headphoneParams.count, preset.layers.count)
        XCTAssertEqual(speakerParams.count, preset.layers.count)

        zip(headphoneParams, speakerParams).forEach { hp, sp in
            if hp.type == .binaural {
                XCTAssertNotEqual(hp.binauralLevel, sp.binauralLevel, "Binaural layers should disable binaural mixes for speakers.")
            }
            XCTAssertNotEqual(hp.carrierFrequency, 0)
            XCTAssertNotEqual(sp.carrierFrequency, 0)
        }
    }
}
