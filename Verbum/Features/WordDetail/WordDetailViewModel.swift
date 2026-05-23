import Foundation
import AVFoundation

class WordDetailViewModel: ObservableObject {
    let word: Word
    private let synthesizer = AVSpeechSynthesizer()

    init(word: Word) {
        self.word = word
    }

    func speakWord() {
        let utterance = AVSpeechUtterance(string: word.text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.4
        synthesizer.speak(utterance)
    }
}
