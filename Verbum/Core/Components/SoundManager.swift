import AVFoundation

/// Plays optional bundled SFX. Silent unless the matching audio file is shipped — the
/// previous synthesized arpeggio sounded cheap, so no-sound is the new default.
///
/// To enable sound: drop a file named `correct_chime.<m4a|mp3|wav|caf|aac>` into the
/// Verbum target's Resources (and `streak_chime.*` for milestones).
@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private var correctChimePlayer: AVAudioPlayer?
    private var streakChimePlayer: AVAudioPlayer?

    private init() {
        correctChimePlayer = loadBundledPlayer(named: "correct_chime")
        streakChimePlayer  = loadBundledPlayer(named: "streak_chime")
    }

    // MARK: - Public

    func playCorrectChime() {
        guard soundEnabled, let player = correctChimePlayer else { return }
        player.currentTime = 0
        player.play()
    }

    func playChime() {
        guard soundEnabled, let player = streakChimePlayer else { return }
        player.currentTime = 0
        player.play()
    }

    /// Kept for API stability with older call sites. No engine to stop in this build.
    func stopEngine() {}

    // MARK: - Private

    private var soundEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
    }

    private func loadBundledPlayer(named name: String) -> AVAudioPlayer? {
        for ext in ["m4a", "mp3", "wav", "caf", "aac"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                return player
            }
        }
        return nil
    }
}
