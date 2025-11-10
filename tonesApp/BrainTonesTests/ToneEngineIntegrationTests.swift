import XCTest
@testable import BrainTones

final class ToneEngineIntegrationTests: XCTestCase {
    private var bundle: Bundle {
        Bundle(for: Self.self)
    }

    func testToneEngineConfiguresAndStartsForPreset() throws {
        let store = PresetStore(bundle: bundle)
        let preset = try XCTUnwrap(store.presets.first)

        let engine = ToneEngine.shared
        try engine.configure(preset: preset, mode: .headphones)
        XCTAssertFalse(engine.isRunning)

        XCTAssertNoThrow(try engine.start())
        XCTAssertTrue(engine.isRunning)

        engine.pause()
        XCTAssertFalse(engine.isRunning)
        engine.stop()
    }
}
