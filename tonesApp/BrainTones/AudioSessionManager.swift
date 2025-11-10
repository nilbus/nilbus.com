import AVFoundation

enum AudioSessionManager {
    static func configureForPlayback() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setActive(true, options: [])
        } catch {
            print("Audio session configuration failed: \(error)")
        }
    }
}
