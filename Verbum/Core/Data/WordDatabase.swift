import Foundation
import GRDB
import os

/// Local SQLite store for the full word database (up to 1,000+ words).
/// Offers both a full fetch (WordRepository materializes it once) and targeted on-demand
/// queries (by level / category / id / FTS). The bundle JSON is the fallback when DB is absent.
///
/// `@unchecked Sendable`: GRDB's `DatabaseQueue` is thread-safe; `dbQueue` is only assigned
/// on the main thread (init, `openIfExists`, the `seedInBackground` completion). All other
/// access is read-only and goes through the queue.
final class WordDatabase: @unchecked Sendable {
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

    /// Bump this whenever Resources/words_v2.db is updated so an app update
    /// re-seeds the writable copy with the new content. Also drives Spotlight re-indexing.
    static let bundledDBVersion = 4
    private static let bundledVersionKey = "verbum.bundledDBVersion"

    private init() {
        // Fast path (every launch after the first): an up-to-date writable copy already
        // exists, so open it synchronously — the feed then has the full catalog before the
        // first render, no skeleton flash.
        if !needsSeeding() {
            openIfExists()
            return
        }
        // Slow path (first launch / bundled-version bump / corrupted copy): copying the
        // bundled DB is the only heavy step and would block launch on the main thread. Do it
        // off-main; until it finishes the app serves the bundled words.json fallback, then
        // upgrades to the full catalog via the .wordDatabaseInstalled notification.
        seedInBackground()
    }

    /// Same staleness test the seed uses — true when the writable copy is missing, older
    /// than the bundled version, or empty/corrupted.
    private func needsSeeding() -> Bool {
        let dest = Self.databaseURL
        let exists = FileManager.default.fileExists(atPath: dest.path)
        let installedVersion = UserDefaults.standard.integer(forKey: Self.bundledVersionKey)
        let isStale = !exists || installedVersion < Self.bundledDBVersion
        let isEmpty = exists && Self.existingDatabaseIsEmpty(at: dest)
        return isStale || isEmpty
    }

    /// Copies the bundled DB on a background queue, then opens it and announces availability
    /// on the main thread so observers (the feed) can reload from the full catalog.
    private func seedInBackground() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.seedFromBundleIfNeeded()
            DispatchQueue.main.async {
                self.openIfExists()
                guard self.isAvailable else { return }
                WordRepository.shared.reloadFromDatabase()
                NotificationCenter.default.post(name: .wordDatabaseInstalled, object: nil)
            }
        }
    }

    func openIfExists() {
        let path = Self.databaseURL.path
        guard FileManager.default.fileExists(atPath: path) else { return }
        do {
            dbQueue = try DatabaseQueue(path: path)
            try runMigrations()
        } catch {
            Logger.database.error("open/migrate failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Copies the bundled 1,000-word database into the writable location on first
    /// launch, when an app update ships a newer bundled version, or when the
    /// existing writable copy is empty (recovers from corrupted/aborted seeds).
    /// The writable copy is needed because the app rebuilds FTS and writes translations.
    private func seedFromBundleIfNeeded() {
        let dest = Self.databaseURL
        let exists = FileManager.default.fileExists(atPath: dest.path)
        let installedVersion = UserDefaults.standard.integer(forKey: Self.bundledVersionKey)
        let isStale = !exists || installedVersion < Self.bundledDBVersion
        let isEmpty = exists && Self.existingDatabaseIsEmpty(at: dest)
        guard isStale || isEmpty else { return }
        guard let bundled = Bundle.main.url(forResource: "words_v2", withExtension: "db") else { return }
        do {
            if exists { try FileManager.default.removeItem(at: dest) }
            try FileManager.default.copyItem(at: bundled, to: dest)
            UserDefaults.standard.set(Self.bundledDBVersion, forKey: Self.bundledVersionKey)
        } catch {
            // Leave any existing database in place if the copy fails.
            Logger.database.error("bundled DB seed failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Returns true when the words table is missing or empty — both indicate an
    /// unusable copy that should be replaced from the bundle.
    private static func existingDatabaseIsEmpty(at url: URL) -> Bool {
        guard let queue = try? DatabaseQueue(path: url.path) else { return true }
        let count = try? queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM words")
        }
        return (count ?? 0) == 0
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
        try runMigrations()
    }

    // MARK: - Migrations

    private static var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()

        m.registerMigration("v1_createWords") { db in
            try db.create(table: "words", ifNotExists: true) { t in
                t.column("id",              .text).primaryKey()
                t.column("text",            .text).notNull()
                t.column("phonetic",        .text).notNull().defaults(to: "")
                t.column("partOfSpeech",    .text).notNull().defaults(to: "")
                t.column("definition",      .text).notNull()
                t.column("exampleSentence", .text)
                t.column("synonyms",        .text).notNull().defaults(to: "[]")
                t.column("category",        .text).notNull().defaults(to: "").indexed()
                t.column("level",           .text).notNull().indexed()
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
                // Match the Python generator's tokenizer so diacritics fold (café == cafe)
                // and search behaves identically whether the DB is bundled or built natively.
                try db.execute(sql: """
                    CREATE VIRTUAL TABLE words_fts USING fts5(
                        text, definition, category,
                        content=words, content_rowid=rowid,
                        tokenize='unicode61 remove_diacritics 2'
                    )
                """)
            }
        }

        m.registerMigration("v2_enrichment") { db in
            try db.alter(table: "words") { t in
                t.add(column: "frequencyRank", .integer)
                t.add(column: "antonyms",      .text)
                t.add(column: "collocations",  .text)
                t.add(column: "register",      .text)
                t.add(column: "domainTags",    .text)
            }
        }

        // v3: per-language catalogues. Existing rows are English; new languages add rows.
        m.registerMigration("v3_language") { db in
            try db.alter(table: "words") { t in
                t.add(column: "language", .text).notNull().defaults(to: "en")
            }
            try db.create(index: "words_language_idx", on: "words",
                          columns: ["language"], ifNotExists: true)
        }

        return m
    }

    func runMigrations() throws {
        guard let dbQueue else { return }
        try Self.migrator.migrate(dbQueue)
    }

    func createSchema() throws { try runMigrations() }

    // MARK: - Translations

    struct Translation: Sendable {
        let definition: String
        let example: String?
    }

    func translation(wordId: UUID, lang: String) -> Translation? {
        if let dbQueue,
           let result = try? dbQueue.read({ db -> Translation? in
               // COLLATE NOCASE: stored ids are lowercase (Python-built bundle) while
               // UUID.uuidString is always uppercase — match case-insensitively so the
               // lookup can't silently miss and fall through to the JSON fallback.
               guard let row = try Row.fetchOne(db, sql: """
                   SELECT definition, example FROM translations
                   WHERE word_id = ? COLLATE NOCASE AND lang = ?
               """, arguments: [wordId.uuidString, lang]) else { return nil }
               return Translation(
                   definition: row["definition"] as? String ?? "",
                   example:    row["example"]    as? String
               )
           }) {
            return result
        }
        return TranslationStore.shared.translation(wordId: wordId, lang: lang)
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
                    """, arguments: [wordId.lowercased(), lang, def, ex])
                }
            }
        }
    }

    // MARK: - Import

    func importWords(_ words: [Word]) throws {
        guard let dbQueue else { return }
        let enc = JSONEncoder()
        func jsonStr<T: Encodable>(_ v: T) -> String? {
            (try? enc.encode(v)).flatMap { String(data: $0, encoding: .utf8) }
        }
        try dbQueue.write { db in
            for word in words {
                try db.execute(sql: """
                    INSERT OR REPLACE INTO words
                    (id, text, phonetic, partOfSpeech, definition,
                     exampleSentence, synonyms, category, level, etymology,
                     frequencyRank, antonyms, collocations, register, domainTags, language)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    // Lowercase to match the bundled DB convention — the primary key is
                    // case-sensitive, so mixing casings would create duplicate word rows.
                    word.id.uuidString.lowercased(), word.text, word.phonetic,
                    word.partOfSpeech, word.definition,
                    word.exampleSentence, jsonStr(word.synonyms) ?? "[]",
                    word.category, word.level.rawValue, word.etymology,
                    word.frequencyRank,
                    jsonStr(word.antonyms) ?? "[]",
                    jsonStr(word.collocations) ?? "[]",
                    word.register?.rawValue,
                    jsonStr(word.domainTags) ?? "[]",
                    word.language
                ])
            }
            try db.execute(sql: "INSERT INTO words_fts(words_fts) VALUES('rebuild')")
        }
    }

    // MARK: - Queries

    /// limit: 0 = no limit (fetch all). `language` nil = all languages.
    func fetchWords(level: WordLevel? = nil, language: String? = nil, offset: Int = 0, limit: Int = 0) -> [Word] {
        guard let dbQueue else { return [] }
        return (try? dbQueue.read { db -> [Word] in
            var conditions: [String] = []
            var args: [DatabaseValueConvertible] = []
            if let level    { conditions.append("level = ?");    args.append(level.rawValue) }
            if let language { conditions.append("language = ?"); args.append(language) }
            var sql = "SELECT * FROM words"
            if !conditions.isEmpty { sql += " WHERE " + conditions.joined(separator: " AND ") }
            if limit > 0 {
                sql += " LIMIT ? OFFSET ?"
                args.append(limit)
                args.append(offset)
            }
            return try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))
                .compactMap(Self.word(from:))
        }) ?? []
    }

    func fetchWords(category: String, language: String? = nil, limit: Int = 0) -> [Word] {
        guard let dbQueue else { return [] }
        return (try? dbQueue.read { db -> [Word] in
            var sql = "SELECT * FROM words WHERE category = ?"
            var args: [DatabaseValueConvertible] = [category]
            if let language { sql += " AND language = ?"; args.append(language) }
            if limit > 0 {
                sql += " LIMIT ?"
                args.append(limit)
            }
            return try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))
                .compactMap(Self.word(from:))
        }) ?? []
    }

    func allCategories(language: String? = nil) -> [String] {
        guard let dbQueue else { return [] }
        return (try? dbQueue.read { db in
            var sql = "SELECT DISTINCT category FROM words"
            var args: [DatabaseValueConvertible] = []
            if let language { sql += " WHERE language = ?"; args.append(language) }
            sql += " ORDER BY category"
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))
            return rows.compactMap { $0["category"] as? String }.filter { !$0.isEmpty }
        }) ?? []
    }

    /// Distinct language codes that have at least one word. Drives the in-app language switcher.
    func availableLanguages() -> [String] {
        guard let dbQueue else { return [] }
        return (try? dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT DISTINCT language FROM words ORDER BY language")
                .compactMap { $0["language"] as? String }
        }) ?? []
    }

    func search(query: String, language: String? = nil, limit: Int = 50) -> [Word] {
        guard let dbQueue else { return [] }
        // Wrap the raw query as a quoted FTS5 string literal + prefix token. Without this,
        // punctuation/operators (" - : ( ^ *) are parsed as FTS5 syntax and throw, which the
        // surrounding try? swallows — so "co-op" or "e.g." would return nothing silently.
        let escaped = query.replacingOccurrences(of: "\"", with: "\"\"")
        let match = "\"\(escaped)\"*"
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return (try? dbQueue.read { db -> [Word] in
            var sql = """
                SELECT w.* FROM words w
                JOIN words_fts ON words_fts.rowid = w.rowid
                WHERE words_fts MATCH ?
            """
            var args: [DatabaseValueConvertible] = [match]
            if let language { sql += " AND w.language = ?"; args.append(language) }
            sql += " LIMIT ?"
            args.append(limit)
            return try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))
                .compactMap(Self.word(from:))
        }) ?? []
    }

    func fetchWords(ids: [UUID]) -> [Word] {
        guard let dbQueue, !ids.isEmpty else { return [] }
        let placeholders = ids.map { _ in "?" }.joined(separator: ",")
        let args = ids.map { $0.uuidString } as [DatabaseValueConvertible]
        return (try? dbQueue.read { db in
            // COLLATE NOCASE: UUID.uuidString is uppercase but the bundled DB stores ids
            // lowercase. Without this the IN-match finds nothing and decks/favorites/history
            // word lookups come back empty when the SQLite source is active.
            try Row.fetchAll(db,
                sql: "SELECT * FROM words WHERE id COLLATE NOCASE IN (\(placeholders))",
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

        let dec = JSONDecoder()
        func jsonArray(_ key: String) -> [String] {
            guard let s = row[key] as? String, let d = s.data(using: .utf8) else { return [] }
            return (try? dec.decode([String].self, from: d)) ?? []
        }

        return Word(
            id:              id,
            text:            text,
            phonetic:        row["phonetic"] as? String ?? "",
            partOfSpeech:    row["partOfSpeech"] as? String ?? "",
            definition:      def,
            exampleSentence: row["exampleSentence"] as? String,
            synonyms:        jsonArray("synonyms"),
            category:        row["category"] as? String ?? "",
            level:           level,
            isNew:           false,
            etymology:       row["etymology"] as? String,
            frequencyRank:   row["frequencyRank"] as? Int,
            antonyms:        jsonArray("antonyms"),
            collocations:    jsonArray("collocations"),
            register:        (row["register"] as? String).flatMap(WordRegister.init),
            domainTags:      jsonArray("domainTags"),
            language:        row["language"] as? String ?? "en"
        )
    }
}
