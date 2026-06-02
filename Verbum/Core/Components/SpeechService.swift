import AVFoundation
import os

// MARK: - Speech

/// Shared speech synthesizer — one instance for the entire app to avoid audio session conflicts.
@MainActor
enum SpeechService {
    private static let synthesizer = AVSpeechSynthesizer()

    /// Speaks `text` in the given vocabulary language's voice. Defaults to the active word
    /// language (the feed/detail words are in that language), so German words sound German and
    /// Ukrainian words Ukrainian — not read aloud with an English voice.
    static func speak(_ text: String, language: String? = nil, rate: Float = 0.42) {
        synthesizer.stopSpeaking(at: .immediate)
        let lang = language ?? LanguageManager.shared.language
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice(for: lang)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    /// Best available voice for a base language code, with regional defaults and an English
    /// fallback if the requested language pack isn't installed on the device.
    private static func voice(for code: String) -> AVSpeechSynthesisVoice? {
        let bcp: String
        switch code {
        case "de": bcp = "de-DE"
        case "uk": bcp = "uk-UA"
        default:   bcp = "en-US"
        }
        return AVSpeechSynthesisVoice(language: bcp)
            ?? AVSpeechSynthesisVoice(language: code)
            ?? AVSpeechSynthesisVoice(language: "en-US")
            ?? AVSpeechSynthesisVoice(language: "en-GB")
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
