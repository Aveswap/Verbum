import Foundation
import AVFoundation

class WordFeedViewModel: ObservableObject {
    @Published var words: [Word] = []
    @Published var currentIndex: Int = 0
    @Published var goingBack: Bool = false

    /// Counts forward swipes since the last quiz — resets on quiz shown and on filter change.
    private(set) var swipesSinceLastQuiz: Int = 0
    /// The last 5 swiped words for the batch quiz.
    private var recentBatchWords: [Word] = []

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
        swipesSinceLastQuiz + 1
    }

    var currentBatchWords: [Word] {
        recentBatchWords
    }

    var isEndOfBatch: Bool {
        swipesSinceLastQuiz == 4
    }

    func nextWord() {
        guard currentIndex < words.count - 1 else { return }
        goingBack = false
        if let word = currentWord {
            recentBatchWords.append(word)
            if recentBatchWords.count > 5 { recentBatchWords.removeFirst() }
        }
        swipesSinceLastQuiz += 1
        currentIndex += 1
    }

    func previousWord() {
        guard currentIndex > 0 else { return }
        goingBack = true
        if swipesSinceLastQuiz > 0 { swipesSinceLastQuiz -= 1 }
        if !recentBatchWords.isEmpty { recentBatchWords.removeLast() }
        currentIndex -= 1
    }

    func resetBatchCounter() {
        swipesSinceLastQuiz = 0
        recentBatchWords = []
    }

    func restartFeed() {
        words = WordRepository.shared.all.shuffled()
        goingBack = false
        currentIndex = 0
        resetBatchCounter()
    }

    func loadWords(_ newWords: [Word]) {
        words = newWords.shuffled()
        currentIndex = 0
        goingBack = false
        resetBatchCounter()
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
