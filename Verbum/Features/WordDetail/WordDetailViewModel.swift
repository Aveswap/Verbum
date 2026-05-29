import Foundation

@MainActor
class WordDetailViewModel: ObservableObject {
    let word: Word

    init(word: Word) {
        self.word = word
    }

    func speakWord() {
        SpeechService.speak(word.text)
    }
}
