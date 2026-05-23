import Foundation
import AVFoundation

class WordFeedViewModel: ObservableObject {
    @Published var words: [Word] = []
    @Published var currentIndex: Int = 0

    private let wordStore = WordStore()
    private let synthesizer = AVSpeechSynthesizer()

    init() {
        self.words = wordStore.words.shuffled()
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

    func nextWord() {
        guard currentIndex < words.count - 1 else { return }
        currentIndex += 1
    }

    func restartFeed() {
        words = words.shuffled()
        currentIndex = 0
    }

    func previousWord() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    func speakWord(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.4
        synthesizer.speak(utterance)
    }
}
