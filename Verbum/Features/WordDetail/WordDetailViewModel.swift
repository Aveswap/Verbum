import Foundation

class WordDetailViewModel: ObservableObject {
    let word: Word
    @Published private(set) var translatedDefinition: String? = nil
    @Published private(set) var translatedExample: String? = nil

    init(word: Word) {
        self.word = word
    }

    func loadTranslation(lang: String) {
        guard !lang.isEmpty, lang != "en" else { return }
        let t = WordDatabase.shared.translation(wordId: word.id, lang: lang)
        translatedDefinition = t?.definition
        translatedExample    = t?.example
    }

    func speakWord() {
        SpeechService.speak(word.text)
    }
}
