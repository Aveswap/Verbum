import AVFoundation

/// Generates tones programmatically — no audio assets needed in the bundle.
final class SoundManager {
    static let shared = SoundManager()

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let sampleRate: Double = 44100

    private init() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.outputNode, format: nil)
        try? engine.start()
    }

    // MARK: - Public

    /// Pleasant ascending C5→E5→G5 arpeggio played when a quiz answer is correct.
    func playCorrectChime() {
        guard soundEnabled else { return }
        let notes: [(freq: Double, delay: Double)] = [
            (523.25, 0.00),   // C5
            (659.25, 0.12),   // E5
            (783.99, 0.24),   // G5
        ]
        for note in notes {
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + note.delay) {
                self.scheduleNote(frequency: note.freq, duration: 0.30, amplitude: 0.35)
            }
        }
    }

    /// Short single chime — used for milestones, streaks, etc.
    func playChime() {
        guard soundEnabled else { return }
        scheduleNote(frequency: 783.99, duration: 0.25, amplitude: 0.3)
    }

    // MARK: - Private

    private var soundEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
    }

    private func scheduleNote(frequency: Double, duration: Double, amplitude: Float) {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        guard let data = buffer.floatChannelData?[0] else { return }
        let attackFrames = Int(sampleRate * 0.02)   // 20 ms attack
        let releaseStart = Int(Double(frameCount) * 0.55)

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let sample = Float(sin(2 * .pi * frequency * t))

            let env: Float
            if frame < attackFrames {
                env = Float(frame) / Float(attackFrames)
            } else if frame >= releaseStart {
                let progress = Float(frame - releaseStart) / Float(Int(frameCount) - releaseStart)
                env = max(0, 1 - progress)
            } else {
                env = 1.0
            }
            data[frame] = amplitude * env * sample
        }

        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: mixer, format: format)
        playerNode.scheduleBuffer(buffer) {
            DispatchQueue.main.async {
                playerNode.stop()
                self.engine.detach(playerNode)
            }
        }
        if !engine.isRunning { try? engine.start() }
        playerNode.play()
    }
}
