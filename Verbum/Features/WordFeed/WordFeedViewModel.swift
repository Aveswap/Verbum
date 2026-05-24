import Foundation
import AVFoundation

class WordFeedViewModel: ObservableObject {
    @Published var words: [Word] = []
    @Published var currentIndex: Int = 0
    @Published var goingBack: Bool = false

    private let wordStore = WordStore()
    private let synthesizer = AVSpeechSynthesizer()

    init() {
        self.words = wordStore.words.shuffled()
        configureAudioSession()
    }

    func filterByCategory(_ category: String?) {
        let all = wordStore.words.shuffled()
        words = category == nil ? all : all.filter { $0.category == category }
        currentIndex = 0
    }

    func filterByLevel(_ level: WordLevel?) {
        let all = wordStore.words.shuffled()
        words = level == nil ? all : all.filter { $0.level == level }
        currentIndex = 0
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

    // Batch progress: 1-5, resets naturally via modulo after quiz
    var batchProgress: Int {
        (currentIndex % 5) + 1
    }

    // Words in the current batch ending at currentIndex
    var currentBatchWords: [Word] {
        let start = max(0, currentIndex - 4)
        return Array(words[start...currentIndex])
    }

    // True when user is at the end of a batch (every 5th word)
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
        words = words.shuffled()
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
        } catch {
            // Audio session configuration is best-effort
        }
    }
}
