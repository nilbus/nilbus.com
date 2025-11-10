import Foundation

enum OutputMode: String, Codable, CaseIterable {
    case headphones
    case speakers
}

enum ToneLayerType: String, Codable {
    case binaural
    case isochronic
}

struct PresetLibrary {
    let presets: [Preset]

    init(jsonURL: URL) throws {
        let data = try Data(contentsOf: jsonURL)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.presets = try decoder.decode([Preset].self, from: data)
    }
}

struct Preset: Codable, Identifiable, Hashable {
    let name: String
    let layers: [ToneLayer]

    var id: String { name }

    func parameters(for mode: OutputMode) -> [ToneLayerParameters] {
        layers.enumerated().map { index, layer in
            layer.parameters(index: index, mode: mode)
        }
    }

    var combinedPurposes: String {
        layers.map(\.purpose).joined(separator: ", ")
    }
}

struct ToneLayer: Codable, Hashable {
    let freq: Double
    let carrier: CarrierSetting
    let type: ToneLayerType
    let volume: VolumeSetting
    let purpose: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        freq = try container.decode(Double.self, forKey: .freq)
        carrier = try container.decode(CarrierSetting.self, forKey: .carrier)
        type = try container.decode(ToneLayerType.self, forKey: .type)
        volume = try container.decode(VolumeSetting.self, forKey: .vol)
        purpose = try container.decode(String.self, forKey: .purpose)
    }

    enum CodingKeys: String, CodingKey {
        case freq
        case carrier
        case type
        case vol
        case purpose
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(freq, forKey: .freq)
        try container.encode(carrier, forKey: .carrier)
        try container.encode(type, forKey: .type)
        try container.encode(volume, forKey: .vol)
        try container.encode(purpose, forKey: .purpose)
    }

    func parameters(index: Int, mode: OutputMode) -> ToneLayerParameters {
        ToneLayerParameters(
            index: index,
            modulationFrequency: freq,
            carrierFrequency: carrier.value(for: mode),
            volume: volume.value(for: mode),
            binauralLevel: type == .binaural && mode == .headphones ? 100 : 0,
            isochronicLevel: type == .binaural && mode == .headphones ? 0 : 100,
            type: type
        )
    }
}

struct CarrierSetting: Codable, Hashable {
    let headphones: Double
    let speakers: Double

    init(value: Double) {
        headphones = value
        speakers = value
    }

    init(headphones: Double, speakers: Double) {
        self.headphones = headphones
        self.speakers = speakers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Double.self) {
            self.init(value: value)
        } else if let stringValue = try? container.decode(String.self) {
            let parts = stringValue.split(separator: "/").compactMap { Double($0) }
            if parts.count == 2 {
                self.init(headphones: parts[0], speakers: parts[1])
            } else if let single = parts.first {
                self.init(value: single)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid carrier format: \(stringValue)")
            }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported carrier value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if headphones == speakers {
            try container.encode(headphones)
        } else {
            try container.encode("\(headphones)/\(speakers)")
        }
    }

    func value(for mode: OutputMode) -> Double {
        switch mode {
        case .headphones:
            return headphones
        case .speakers:
            return speakers
        }
    }
}

struct VolumeSetting: Codable, Hashable {
    let headphones: Double
    let speakers: Double

    init(value: Double) {
        headphones = value
        speakers = value
    }

    init(headphones: Double, speakers: Double) {
        self.headphones = headphones
        self.speakers = speakers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Double.self) {
            self.init(value: value)
        } else if let stringValue = try? container.decode(String.self) {
            let parts = stringValue.split(separator: "/").compactMap { Double($0) }
            if parts.count == 2 {
                self.init(headphones: parts[0], speakers: parts[1])
            } else if let single = parts.first {
                self.init(value: single)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid volume format: \(stringValue)")
            }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported volume value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if headphones == speakers {
            try container.encode(headphones)
        } else {
            try container.encode("\(headphones)/\(speakers)")
        }
    }

    func value(for mode: OutputMode) -> Double {
        switch mode {
        case .headphones:
            return headphones
        case .speakers:
            return speakers
        }
    }
}

struct ToneLayerParameters: Hashable {
    let index: Int
    let modulationFrequency: Double
    let carrierFrequency: Double
    let volume: Double
    let binauralLevel: Double
    let isochronicLevel: Double
    let type: ToneLayerType
}
