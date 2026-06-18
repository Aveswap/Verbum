import AVFoundation
import os

// MARK: - Speech

/// Shared speech synthesizer — one instance for the entire app to avoid audio session conflicts.
///
/// The audio session is held only while actually speaking: `speak()` activates it and the
/// synthesizer delegate deactivates it on finish/cancel. Holding an active `.playback` session
/// for the whole app lifetime (the old behaviour) needlessly interrupts other audio and keeps
/// the route alive when nothing is playing. `.playback` (not `.ambient`) is deliberate so a
/// pronunciation still plays when the ringer switch is on silent — that's expected for a
/// "tap to hear the word" feature.
@MainActor
enum SpeechService {
    private static let synthesizer: AVSpeechSynthesizer = {
        let s = AVSpeechSynthesizer()
        s.delegate = sessionGuard
        return s
    }()
    /// Deactivates the session when speech ends. Held strongly here; the synthesizer's
    /// `delegate` is weak.
    private static let sessionGuard = SpeechSessionGuard()

    /// Speaks `text` in the given vocabulary language's voice. Defaults to the active word
    /// language (the feed/detail words are in that language), so German words sound German and
    /// Ukrainian words Ukrainian — not read aloud with an English voice.
    static func speak(_ text: String, language: String? = nil, rate: Float = 0.42) {
        synthesizer.stopSpeaking(at: .immediate)
        activateSession()
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

    /// Sets the category once (cheap, doesn't grab the session). Safe to call at feed init;
    /// the session is only made active lazily, around an actual `speak()`.
    static func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .voicePrompt,
                options: [.mixWithOthers, .allowBluetoothHFP]
            )
        } catch {
            Logger.speech.error("audio session category setup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    fileprivate static func activateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            Logger.speech.error("audio session activate failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    fileprivate static func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // A failed deactivation is benign (often "session already inactive"); log at debug.
            Logger.speech.debug("audio session deactivate skipped: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// Releases the shared audio session as soon as the synthesizer goes idle. The delegate
/// callbacks arrive on an arbitrary queue, so each hops to the main actor.
private final class SpeechSessionGuard: NSObject, AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in SpeechService.deactivateSession() }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in SpeechService.deactivateSession() }
    }
}
