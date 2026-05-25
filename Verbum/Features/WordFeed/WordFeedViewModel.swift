import Foundation
import AVFoundation

class WordFeedViewModel: ObservableObject {
    @Published var words: [Word] = []
    @Published var currentIndex: Int = 0
    @Published var goingBack: Bool = false

    private let synthesizer = AVSpeechSynthesizer()

    init() {
        self.words = WordRepository.shared.all.shuffled()
        configureAudioSession()
    }

    var currentWord: Word? {
        guard !words.isEmpty, words.indices.contains(currentIndex) else { return nil }
        return words[currentIndex]
    }

    var isAtEnd: Bool {
        !words.isEmpty && currentIndex >= words.count - 1
    }

    var isAtStart: Bool {
        currentIndex == 0
    }

    var batchProgress: Int {
        (currentIndex % 5) + 1
    }

    var currentBatchWords: [Word] {
        guard !words.isEmpty, words.indices.contains(currentIndex) else { return [] }
        let start = max(0, currentIndex - 4)
        return Array(words[start...currentIndex])
    }

    var isEndOfBatch: Bool {
        batchProgress == 5
    }

    func nextWord() {
        guard currentIndex < words.count - 1 else { return }
        goingBack = false
        currentIndex += 1
    }

    func previousWord() {
        guard currentIndex > 0 else { return }
        goingBack = true
        currentIndex -= 1
    }

    func restartFeed() {
        words = WordRepository.shared.all.shuffled()
        goingBack = false
        currentIndex = 0
    }

    func speakWord(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            ?? AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.42
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .voicePrompt,
                options: [.mixWithOthers, .allowBluetoothHFP]
            )
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {}
    }
}
