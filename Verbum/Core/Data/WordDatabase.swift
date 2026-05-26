import Foundation
import GRDB

/// Local SQLite store for the full word database (up to 1,000+ words).
/// Words are queried on-demand; the bundle JSON is the fallback when DB is absent.
final class WordDatabase {
    static let shared = WordDatabase()

    private(set) var dbQueue: DatabaseQueue?

    static var databaseURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
                             .appendingPathComponent("Verbum", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir,
                                                  withIntermediateDirectories: true)
        return dir.appendingPathComponent("words.db")
    }

    var isAvailable: Bool { dbQueue != nil }

    private init() { openIfExists() }

    func openIfExists() {
        let path = Self.databaseURL.path
        guard FileManager.default.fileExists(atPath: path) else { return }
        dbQueue = try? DatabaseQueue(path: path)
    }

    // MARK: - Install

    /// Moves the downloaded file into place and opens the queue.
    func install(from tempURL: URL) throws {
        let dest = Self.databaseURL
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempURL, to: dest)
        dbQueue = try DatabaseQueue(path: dest.path)
        try createSchema()
    }

    // MARK: - Schema

    func createSchema() throws {
        guard let dbQueue else { return }
        try dbQueue.write { db in
            try db.create(table: "words", ifNotExists: true) { t in
                t.column("id",              .text).primaryKey()
                t.column("text",            .text).notNull()
                t.column("phonetic",        .text).notNull().defaults(to: "")
                t.column("partOfSpeech",    .text).notNull().defaults(to: "")
                t.column("definition",      .text).notNull()
                t.column("exampleSentence", .text)
                t.column("synonyms",        .text).notNull().defaults(to: "[]")
                t.column("category",        .text).notNull().defaults(to: "")
                t.column("level",           .text).notNull()
                t.column("etymology",       .text)
            }
            try db.create(table: "translations", ifNotExists: true) { t in
                t.column("word_id",    .text).notNull().references("words", onDelete: .cascade)
                t.column("lang",       .text).notNull()
                t.column("definition", .text).notNull()
                t.column("example",    .text)
                t.primaryKey(["word_id", "lang"])
            }
            if try !db.tableExists("words_fts") {
                try db.execute(sql: """
                    CREATE VIRTUAL TABLE words_fts USING fts5(
                        text, definition, category,
                        content=words, content_rowid=rowid
                    )
                """)
            }
        }
    }

    // MARK: - Translations

    struct Translation {
        let definition: String
        let example: String?
    }

    func translation(wordId: UUID, lang: String) -> Translation? {
        guard let dbQueue else { return nil }
        return try? dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT definition, example FROM translations
                WHERE word_id = ? AND lang = ?
            """, arguments: [wordId.uuidString.lowercased(), lang]) else { return nil }
            return Translation(
                definition: row["definition"] as? String ?? "",
                example:    row["example"]    as? String
            )
        }
    }

    func importTranslations(_ bundle: [String: [String: [String: String?]]]) throws {
        // bundle format: { lang: { wordId: { "d": def, "e": example? } } }
        guard let dbQueue else { return }
        try dbQueue.write { db in
            for (lang, entries) in bundle {
                for (wordId, fields) in entries {
                    guard let def = fields["d"] as? String else { continue }
                    let ex = fields["e"] as? String
                    try db.execute(sql: """
                        INSERT OR REPLACE INTO translations (word_id, lang, definition, example)
                        VALUES (?, ?, ?, ?)
                    """, arguments: [wordId, lang, def, ex])
                }
            }
        }
    }

    // MARK: - Import

    func importWords(_ words: [Word]) throws {
        guard let dbQueue else { return }
        let encoder = JSONEncoder()
        try dbQueue.write { db in
            for word in words {
                let synonymsJSON = (try? encoder.encode(word.synonyms))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
                try db.execute(sql: """
                    INSERT OR REPLACE INTO words
                    (id, text, phonetic, partOfSpeech, definition,
                     exampleSentence, synonyms, category, level, etymology)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    word.id.uuidString, word.text, word.phonetic,
                    word.partOfSpeech, word.definition,
                    word.exampleSentence, synonymsJSON,
                    word.category, word.level.rawValue, word.etymology
                ])
            }
            try db.execute(sql: "INSERT INTO words_fts(words_fts) VALUES('rebuild')")
        }
    }

    // MARK: - Queries

    /// limit: 0 = no limit (fetch all)
    func fetchWords(level: WordLevel? = nil, offset: Int = 0, limit: Int = 0) -> [Word] {
        guard let dbQueue else { return [] }
        return (try? dbQueue.read { db -> [Word] in
            var sql = "SELECT * FROM words"
            var args: [DatabaseValueConvertible] = []
            if let level {
                sql += " WHERE level = ?"
                args.append(level.rawValue)
            }
            if limit > 0 {
                sql += " LIMIT ? OFFSET ?"
                args.append(limit)
                args.append(offset)
            }
            return try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))
                .compactMap(Self.word(from:))
        }) ?? []
    }

    func fetchWords(category: String, limit: Int = 0) -> [Word] {
        guard let dbQueue else { return [] }
        return (try? dbQueue.read { db -> [Word] in
            var sql = "SELECT * FROM words WHERE category = ?"
            var args: [DatabaseValueConvertible] = [category]
            if limit > 0 {
                sql += " LIMIT ?"
                args.append(limit)
            }
            return try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))
                .compactMap(Self.word(from:))
        }) ?? []
    }

    func allCategories() -> [String] {
        guard let dbQueue else { return [] }
        return (try? dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT DISTINCT category FROM words ORDER BY category")
            return rows.compactMap { $0["category"] as? String }.filter { !$0.isEmpty }
        }) ?? []
    }

    func search(query: String, limit: Int = 50) -> [Word] {
        guard let dbQueue, !query.isEmpty else { return [] }
        return (try? dbQueue.read { db -> [Word] in
            try Row.fetchAll(db, sql: """
                SELECT w.* FROM words w
                JOIN words_fts ON words_fts.rowid = w.rowid
                WHERE words_fts MATCH ?
                LIMIT ?
            """, arguments: [query + "*", limit])
            .compactMap(Self.word(from:))
        }) ?? []
    }

    func fetchWords(ids: [UUID]) -> [Word] {
        guard let dbQueue, !ids.isEmpty else { return [] }
        let placeholders = ids.map { _ in "?" }.joined(separator: ",")
        let args = ids.map { $0.uuidString } as [DatabaseValueConvertible]
        return (try? dbQueue.read { db in
            try Row.fetchAll(db,
                sql: "SELECT * FROM words WHERE id IN (\(placeholders))",
                arguments: StatementArguments(args))
            .compactMap(Self.word(from:))
        }) ?? []
    }

    func totalCount() -> Int {
        guard let dbQueue else { return 0 }
        return (try? dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM words")
        }) ?? 0
    }

    func todaysWord() -> Word? {
        guard let dbQueue else { return nil }
        let count = totalCount()
        guard count > 0 else { return nil }
        let dayIndex = (Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1) - 1
        let offset = dayIndex % count
        return fetchWords(offset: offset, limit: 1).first
    }

    // MARK: - Row → Word

    private static func word(from row: Row) -> Word? {
        guard let idStr    = row["id"] as? String,
              let id       = UUID(uuidString: idStr),
              let text     = row["text"] as? String,
              let levelStr = row["level"] as? String,
              let level    = WordLevel(rawValue: levelStr),
              let def      = row["definition"] as? String
        else { return nil }

        let synonymsData = (row["synonyms"] as? String)?.data(using: .utf8)
        let synonyms = (synonymsData.flatMap {
            try? JSONDecoder().decode([String].self, from: $0)
        }) ?? []

        return Word(
            id:              id,
            text:            text,
            phonetic:        row["phonetic"] as? String ?? "",
            partOfSpeech:    row["partOfSpeech"] as? String ?? "",
            definition:      def,
            exampleSentence: row["exampleSentence"] as? String,
            synonyms:        synonyms,
            category:        row["category"] as? String ?? "",
            level:           level,
            isNew:           false,
            etymology:       row["etymology"] as? String
        )
    }
}
