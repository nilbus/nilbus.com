import AVFoundation

final class ToneLayerNode {
    private struct Constants {
        static let twoPi = Double.pi * 2
        static let carrierBaseMin: Double = 27.5
        static let carrierOctaves: Double = 9.0
    }

    private let parameters: ToneLayerParameters
    private let sampleRate: Double
    private let format: AVAudioFormat
    private lazy var node: AVAudioSourceNode = {
        let sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard buffers.count >= 2 else { return noErr }

            let leftBuffer = buffers[0]
            let rightBuffer = buffers[1]
            guard let leftPointer = leftBuffer.mData?.assumingMemoryBound(to: Float.self),
                  let rightPointer = rightBuffer.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }

            var localLeftPhase = self.leftPhase
            var localRightPhase = self.rightPhase
            var localModulationPhase = self.modulationPhase

            for frame in 0..<Int(frameCount) {
                let isoValue = self.isochronicGain > 0
                    ? self.baseGain + self.isochronicGain * sin(localModulationPhase)
                    : self.baseGain
                let amplitude = self.gainFactor * max(0.0, min(1.0, isoValue))

                let leftSample = sin(localLeftPhase) * amplitude
                let rightSample = sin(localRightPhase) * amplitude

                leftPointer[frame] = Float(leftSample)
                rightPointer[frame] = Float(rightSample)

                localLeftPhase += self.leftIncrement
                if localLeftPhase >= Constants.twoPi { localLeftPhase -= Constants.twoPi }
                localRightPhase += self.rightIncrement
                if localRightPhase >= Constants.twoPi { localRightPhase -= Constants.twoPi }

                localModulationPhase += self.modulationIncrement
                if localModulationPhase >= Constants.twoPi { localModulationPhase -= Constants.twoPi }
            }

            self.leftPhase = localLeftPhase
            self.rightPhase = localRightPhase
            self.modulationPhase = localModulationPhase

            return noErr
        }
        return sourceNode
    }()

    private var leftPhase: Double = 0
    private var rightPhase: Double = 0
    private var modulationPhase: Double = 0

    private let leftIncrement: Double
    private let rightIncrement: Double
    private let modulationIncrement: Double
    private let gainFactor: Double
    private let baseGain: Double
    private let isochronicGain: Double

    init?(parameters: ToneLayerParameters, sampleRate: Double) {
        self.parameters = parameters
        self.sampleRate = sampleRate

        guard let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            return nil
        }
        format = audioFormat

        let binauralOffset = (parameters.modulationFrequency / 2.0) * (parameters.binauralLevel / 100.0)
        leftIncrement = Constants.twoPi * (parameters.carrierFrequency + binauralOffset) / sampleRate
        rightIncrement = Constants.twoPi * (parameters.carrierFrequency - binauralOffset) / sampleRate
        modulationIncrement = Constants.twoPi * parameters.modulationFrequency / sampleRate

        gainFactor = pow(parameters.volume / 100.0, 2.0)

        let fmax = pow(2.0, Constants.carrierOctaves) * Constants.carrierBaseMin
        let carrierRatio = parameters.carrierFrequency / fmax
        let base = max(0.0, 0.5 * (1.0 - 0.5 * carrierRatio) * (1.0 - 0.6 * carrierRatio))
        baseGain = base
        isochronicGain = base * (parameters.isochronicLevel / 100.0)
    }

    func attach(to engine: AVAudioEngine) {
        let format = node.outputFormat(forBus: 0)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    func detach(from engine: AVAudioEngine) {
        engine.disconnectNodeInput(node)
        engine.detach(node)
    }
}
