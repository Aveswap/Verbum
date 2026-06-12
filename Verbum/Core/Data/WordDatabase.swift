import Foundation
import GRDB
import os

/// Local SQLite store for the full word database (up to 1,000+ words).
/// Offers both a full fetch (WordRepository materializes it once) and targeted on-demand
/// queries (by level / category / id / FTS). The bundle JSON is the fallback when DB is absent.
///
/// `@unchecked Sendable`: GRDB's `DatabaseQueue` is itself thread-safe, and the optional
/// reference to it is guarded by `queueLock` (an `OSAllocatedUnfairLock`). The reference is
/// written from the seeding background queue and the main thread, and read from any queue,
/// so the lock — not a "main-thread-only" convention — is what makes the access well-defined.
final class WordDatabase: @unchecked Sendable {
    static let shared = WordDatabase()

    /// The live connection. Reads take the lock and copy out the reference; the `DatabaseQueue`
    /// it returns is internally synchronized, so callers can use it without holding the lock.
    private let queueLock = OSAllocatedUnfairLock<DatabaseQueue?>(initialState: nil)
    var dbQueue: DatabaseQueue? { queueLock.withLock { $0 } }
    private func setQueue(_ queue: DatabaseQueue?) { queueLock.withLock { $0 = queue } }

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
    /// v5: added the Ukrainian catalogue + `language` column (see scripts/build_uk_catalog.py).
    /// v6: added the German beginner free-pool catalogue (see scripts/build_de_catalog.py).
    /// v7: German free pool complete — 50 beginner + 50 intermediate + 50 expert.
    /// v8: German beginner expansion → 100 beginner (de now 200 total).
    /// v9: German intermediate expansion → 100 intermediate (de now 250 total).
    /// v10: German expert expansion → 100 each level (de now 300 total).
    /// v11: German beginner expansion → 150 beginner (de now 350 total).
    /// v12: German intermediate expansion → 150 intermediate (de now 400 total).
    /// v13: German expert expansion → 150 each level (de now 450 total).
    /// v14: German beginner expansion → 200 beginner (de now 500 total — halfway).
    /// v15: German intermediate expansion → 200 intermediate (de now 550 total).
    /// v16: German expert expansion → 200 each level (de now 600 total).
    /// v17: German beginner expansion incl. premium categories → 250 beginner (de now 650).
    /// v18: German beginner COMPLETE → 300 beginner (de now 700 total).
    /// v19: Ukrainian de-duplicated by lemma — 1000 → 892 distinct words (scripts/build_uk_catalog.py).
    /// v20: German COMPLETE — 300/450/250 = 1000 words, at parity with English (batches 16–20).
    /// v21: curated "wow-tier" gems (deep research) — +70 standalone words (en 1016 / de 1023 / uk 923),
    ///      33 seeded into the free pool (scripts/import_gems.py + word_batches_gems/).
    /// v22: pruned 740 boring/over-common words (deep-research audit) — en 767 / de 793 / uk 662; gems + free-pool floors preserved.
    /// v23: round-2 gems (+28 authored: en 777 / de 803 / uk 670; freePool seeded, non-premium).
    /// v24: PIVOT — curated gems only; deleted all 2137 non-gem words (de 37 / en 35 / uk 41). See scripts/keep_gems_only.py.
    /// v25: removed difficulty levels entirely (WordLevel enum + `level` column dropped); English-only base
    ///      (de/uk rows deleted, recoverable via word_batches; en 35). Every word is now just "an interesting word".
    /// v26: +50 curated "wow-tier" words (deep-research round 3 → en 85); 27 freePool-seeded
    ///      (scripts/word_batches_gems/gems_round3.json). scurryfunge recategorized Society→General.
    /// v27: +50 more curated words (deep-research round 4 → en 135; gems_round4.json), 19 freePool.
    /// v28: +96 curated words (deep-research round 5 → en 231; gems_round5.json). NOTE: 48 of these
    ///      (the shorthand half of that batch) have no exampleSentence yet — backfill later.
    /// v29: removed those 48 weaker, example-less words → en 183. Every word now has an example
    ///      sentence; the catalogue is uniformly the higher-quality curated set.
    static let bundledDBVersion = 29
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
            setQueue(try DatabaseQueue(path: path))
            try runMigrations()
        } catch {
            Logger.database.error("open/migrate failed: \(error.localizedDescription, privacy: .public)")
            // Don't expose a half-migrated / unopenable DB as "available" — drop the queue so
            // isAvailable becomes false and callers fall back to the bundle / a fresh re-seed,
            // instead of silently returning [] from every query against a broken schema.
            setQueue(nil)
        }
    }

    /// Copies the bundled database into the writable location on first launch, when an app
    /// update ships a newer bundled version, or when the existing writable copy is empty
    /// (recovers from corrupted/aborted seeds).
    ///
    /// INVARIANT: `words.db` is a **disposable content cache** — re-seeding wipes it wholesale.
    /// All user-generated state (progress, streaks, decks, reviews, settings) lives in
    /// `UserProfile` (UserDefaults + CloudKit), NOT here, so a re-seed loses nothing the user
    /// created. Any FUTURE writable content in this DB (OTA word packs, downloaded translations)
    /// MUST either live in a separate file or be re-applied after a re-seed — do not assume rows
    /// written here survive a `bundledDBVersion` bump.
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

    enum InstallError: Error { case downloadedDatabaseInvalid }

    /// Validates a downloaded DB, then atomically swaps it into place and opens it.
    ///
    /// SECURITY: a production OTA pipeline MUST verify a SHA-256 (or signature) from a *signed
    /// manifest* before calling this — the sanity check below authenticates the file's *shape*,
    /// not its *source*, so it does not by itself defend against a compromised CDN / MITM. See
    /// `DatabaseDownloadManager`. Until that exists, the OTA path stays dormant (DB is bundled).
    func install(from tempURL: URL) throws {
        // 1) Integrity sanity check BEFORE touching the live DB: it must open as SQLite and hold
        //    words. Rejects truncated / corrupt / empty payloads. Scoped so the probe handle is
        //    released before the swap.
        do {
            let probe = try DatabaseQueue(path: tempURL.path)
            let count = (try? probe.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM words") }) ?? 0
            guard count > 0 else { throw InstallError.downloadedDatabaseInvalid }
        }

        // 2) Atomic replace — a crash mid-swap must never leave the user with no database.
        let dest = Self.databaseURL
        setQueue(nil)  // release our open handle so the live file can be replaced
        if FileManager.default.fileExists(atPath: dest.path) {
            _ = try FileManager.default.replaceItemAt(dest, withItemAt: tempURL)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: dest)
        }
        setQueue(try DatabaseQueue(path: dest.path))
        try runMigrations()

        // 3) Mark installed so the next launch's seed doesn't clobber this copy with the bundle.
        UserDefaults.standard.set(Self.bundledDBVersion, forKey: Self.bundledVersionKey)
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
        // Surface schema drift: if the code expects migrations the DB doesn't have applied
        // (e.g. a forward-rolled bundled DB opened by an older build, or a half-applied
        // migration), log it rather than failing silently with mysterious query errors.
        if let applied = try? dbQueue.read({ try Self.migrator.appliedIdentifiers($0) }) {
            let expected = Set(Self.migrator.migrations)
            let missing = expected.subtracting(applied)
            let unknown = applied.subtracting(expected)
            if !missing.isEmpty {
                Logger.database.error("migration drift: expected-but-not-applied \(missing.sorted().joined(separator: ", "), privacy: .public)")
            }
            if !unknown.isEmpty {
                Logger.database.error("migration drift: applied-but-unknown \(unknown.sorted().joined(separator: ", "), privacy: .public)")
            }
        }
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
                     exampleSentence, synonyms, category, etymology,
                     frequencyRank, antonyms, collocations, register, domainTags, language)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    // Lowercase to match the bundled DB convention — the primary key is
                    // case-sensitive, so mixing casings would create duplicate word rows.
                    word.id.uuidString.lowercased(), word.text, word.phonetic,
                    word.partOfSpeech, word.definition,
                    word.exampleSentence, jsonStr(word.synonyms) ?? "[]",
                    word.category, word.etymology,
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
    func fetchWords(language: String? = nil, offset: Int = 0, limit: Int = 0) -> [Word] {
        guard let dbQueue else { return [] }
        return (try? dbQueue.read { db -> [Word] in
            var conditions: [String] = []
            var args: [DatabaseValueConvertible] = []
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

    func fetchWords(ids: [UUID], language: String? = nil) -> [Word] {
        guard let dbQueue, !ids.isEmpty else { return [] }
        let placeholders = ids.map { _ in "?" }.joined(separator: ",")
        var args = ids.map { $0.uuidString } as [DatabaseValueConvertible]
        var sql = "SELECT * FROM words WHERE id COLLATE NOCASE IN (\(placeholders))"
        if let language { sql += " AND language = ?"; args.append(language) }
        return (try? dbQueue.read { db in
            // COLLATE NOCASE: UUID.uuidString is uppercase but the bundled DB stores ids
            // lowercase. Without this the IN-match finds nothing and decks/favorites/history
            // word lookups come back empty when the SQLite source is active.
            // `language` scopes saved lists (decks/favorites/history) to the active catalogue,
            // so switching language doesn't show the previous language's words.
            try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))
                .compactMap(Self.word(from:))
        }) ?? []
    }

    func totalCount() -> Int {
        guard let dbQueue else { return 0 }
        return (try? dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM words")
        }) ?? 0
    }

    /// Word of the day for a single language, deterministic across rebuilds.
    func todaysWord(language: String) -> Word? {
        guard let dbQueue else { return nil }
        return try? dbQueue.read { db -> Word? in
            let total = try Int.fetchOne(db,
                sql: "SELECT COUNT(*) FROM words WHERE language = ?", arguments: [language]) ?? 0
            guard total > 0 else { return nil }
            let dayIndex = (Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1) - 1
            let offset = dayIndex % total
            // Stable order: physical row order is not guaranteed and shifts on every rebuild.
            let row = try Row.fetchOne(db, sql: """
                SELECT * FROM words WHERE language = ?
                ORDER BY frequencyRank IS NULL, frequencyRank, id
                LIMIT 1 OFFSET ?
            """, arguments: [language, offset])
            return row.flatMap(Self.word(from:))
        }
    }

    // MARK: - Row → Word

    private static func word(from row: Row) -> Word? {
        guard let idStr    = row["id"] as? String,
              let id       = UUID(uuidString: idStr),
              let text     = row["text"] as? String,
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
