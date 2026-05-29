import AVFoundation

// MARK: - Tone synthesis

/// Synthesizes tones via a pre-allocated AVAudioPlayerNode pool.
/// No audio assets needed. Pool eliminates per-note attach/detach overhead.
@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private let engine  = AVAudioEngine()
    private let mixer   = AVAudioMixerNode()
    private let format  = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

    // 4-node pool — enough for a 3-note chime + 1 overlap buffer
    private let pool: [AVAudioPlayerNode] = (0..<4).map { _ in AVAudioPlayerNode() }
    private var poolIndex = 0

    private init() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.outputNode, format: nil)
        for node in pool {
            engine.attach(node)
            engine.connect(node, to: mixer, format: format)
        }
        // Engine is started lazily in scheduleNote() when sound is actually requested.
        // Avoids holding the audio session active when sound is disabled.
    }

    /// Stops the engine when sound is disabled — releases the audio session and saves battery.
    func stopEngine() {
        if engine.isRunning { engine.stop() }
    }

    // MARK: - Public

    /// Ascending C5 → E5 → G5 arpeggio on correct quiz answer.
    func playCorrectChime() {
        guard soundEnabled else { return }
        let notes: [(freq: Double, delay: Double)] = [
            (523.25, 0.00),   // C5
            (659.25, 0.12),   // E5
            (783.99, 0.24),   // G5
        ]
        for note in notes {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(note.delay * 1_000_000_000))
                self?.scheduleNote(frequency: note.freq, duration: 0.30, amplitude: 0.35)
            }
        }
    }

    /// Single G5 chime — for streaks / milestones.
    func playChime() {
        guard soundEnabled else { return }
        scheduleNote(frequency: 783.99, duration: 0.25, amplitude: 0.30)
    }

    // MARK: - Private

    private var soundEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
    }

    private func scheduleNote(frequency: Double, duration: Double, amplitude: Float) {
        guard soundEnabled else { stopEngine(); return }
        let sampleRate  = format.sampleRate
        let frameCount  = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data   = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frameCount

        let attackFrames  = Int(sampleRate * 0.02)
        let releaseStart  = Int(Double(frameCount) * 0.55)

        for frame in 0..<Int(frameCount) {
            let t   = Double(frame) / sampleRate
            let raw = Float(sin(2 * .pi * frequency * t))
            let env: Float
            if frame < attackFrames {
                env = Float(frame) / Float(attackFrames)
            } else if frame >= releaseStart {
                let progress = Float(frame - releaseStart) / Float(Int(frameCount) - releaseStart)
                env = max(0, 1 - progress)
            } else {
                env = 1.0
            }
            data[frame] = amplitude * env * raw
        }

        let node = nextPoolNode()
        if !engine.isRunning { try? engine.start() }
        node.scheduleBuffer(buffer, completionHandler: nil)
        if !node.isPlaying { node.play() }
    }

    private func nextPoolNode() -> AVAudioPlayerNode {
        let node = pool[poolIndex]
        poolIndex = (poolIndex + 1) % pool.count
        return node
    }
}
