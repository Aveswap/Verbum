import AVFoundation
import os

// MARK: - Speech

/// Shared speech synthesizer — one instance for the entire app to avoid audio session conflicts.
@MainActor
enum SpeechService {
    private static let synthesizer = AVSpeechSynthesizer()

    static func speak(_ text: String, rate: Float = 0.42) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            ?? AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = rate
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    static func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .voicePrompt,
                options: [.mixWithOthers, .allowBluetoothHFP]
            )
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            Logger.speech.error("audio session setup failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
