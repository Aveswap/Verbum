import Foundation
import AVFoundation

class WordFeedViewModel: ObservableObject {
    @Published var words: [Word] = []
    @Published var currentIndex: Int = 0

    private let wordStore = WordStore()
    private let synthesizer = AVSpeechSynthesizer()

    init() {
        self.words = wordStore.words
    }

    var currentWord: Word? {
        guard !words.isEmpty, words.indices.contains(currentIndex) else { return nil }
        return words[currentIndex]
    }

    func nextWord() {
        guard currentIndex < words.count - 1 else { return }
        currentIndex += 1
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
