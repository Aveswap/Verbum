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
    /// v30: +60 genuine "wow" concept-words (deep-research round 6 → en 243; gems_round6.json),
    ///      all with example sentences; 29 freePool. komorebi, treppenwitz, mokita, sisu, kilig…
    /// v31: +60 dictionary-verified wow words (deep-research round 7 → en 303; gems_round7.json),
    ///      all with examples; 34 freePool. weltschmerz, zugzwang, grok, hangry, gobsmacked, cwtch…
    /// v32: editorial — Verbum is an ENGLISH-vocabulary app, so cut 43 non-naturalized foreign
    ///      "untranslatable" words (verschlimmbessern, Torschlusspanik, fika, …) that aren't in
    ///      English dictionaries → en 260. Kept English-dialect/naturalized loanwords + ~15 iconic
    ///      untranslatables (~5%: komorebi, sobremesa, sisu, tsundoku, wabi-sabi, …) as flavour.
    /// v33: emptied the dead `translations` table (1000 stale uk/de rows from before the pivot) +
    ///      VACUUM — bundled DB shrank 1.8 MB → 216 KB. Words unchanged (en 260).
    /// v34: +102 rare REAL English dictionary words (deep-research batches 8+9, deduped → en 362;
    ///      gems_round8.json). All OED/M-W/Collins headwords with examples; dropped saudade
    ///      (foreign untranslatable). threnody, palimpsest, lacuna, sangfroid, pellucid, quiddity…
    /// v35: +100 rare REAL English dictionary words (deep-research round 9, deduped → en 462;
    ///      gems_round9.json). OED/M-W/Collins headwords with examples; ~5 iconic untranslatables
    ///      kept as flavour (toska, fernweh, mudita…). syzygy, pareidolia, sfumato, interrobang,
    ///      marcescence, gamboge, hoarfrost, aposiopesis, boustrophedon, philtrum…
    /// v36: editorial cleanup — removed 17 non-dictionary entries → en 445. Cut 3 invented
    ///      neologisms (sonder, anemoia, compersion — blog/community coinages, not OED/M-W/Collins
    ///      headwords) and 14 pure foreign untranslatables, trimming the "flavour" loanwords back
    ///      to ~15 iconic ones (~5%: komorebi, hiraeth, sisu, wabi-sabi, toska, fernweh, tsundoku…).
    /// v37: removed 11 multi-word foreign-language phrases that read as another language, not
    ///      English (l'esprit de l'escalier, à la belle étoile, coup de foudre, dolce far niente,
    ///      jolie laide, mono no aware, sub rosa, vade mecum, eminence grise, jamais vu, hapax
    ///      legomenon) → en 434. Kept the English idiom "brown study".
    /// v38: imported gems_round10 (+70 dictionary-attested gems weighted into the under-
    ///      represented categories — Movement, Time, Literature, Body, Science, Mind, Society,
    ///      Language) → en 504.
    /// v39: imported gems_round11 (+70 dictionary-verified gems concentrated in the still-thin
    ///      buckets — Communication 13, Emotions 9, Science 9, Art 8, Body 7, Language 6,
    ///      Society 6, Food 5, Psychology 4, Time 3) → en 574.
    /// v40: imported gems_round12 (+100 emotion/nature/sensory "wow" words — twilight & weather,
    ///      landscape, water, melancholy & joy feelings, untranslatables like hygge) → en 674.
    /// v41: imported gems_round13 (+100 more "wow" words — bibelot, ruth, desuetude, …) → en 774.
    /// v42: imported gems_round14 (+100 more "wow" words — mono no aware, hwyl, tristesse, …) → en 874.
    /// v43: imported gems_round15 (+100 more, deeper cuts — scunner, thrawn, wheesht, …) → en 974.
    static let bundledDBVersion = 43

    private init() {
        // The catalogue is read-only at runtime (nothing in the app writes to `words`), so we
        // open the bundled `words_v2.db` directly, in place, with a read-only connection. No
        // copy into Application Support, no migration, no background seed — the full catalog is
        // available synchronously before the first render. This is what makes the very first
        // launch fast: the old code copied a ~280 KB DB off-main and only upgraded the feed from
        // the words.json fallback once the copy + open + reload round-trip finished.
        //
        // The bundled DB already has every migration applied (v1–v3) and its FTS index built, so
        // there is nothing to run at open time. words.json remains the fallback if this fails.
        openBundledReadOnly()
    }

    /// Opens the bundled `words_v2.db` read-only, in place. Read-only is required because the app
    /// bundle is not writable on device; it also documents the invariant that the catalogue is
    /// immutable at runtime. On failure the queue stays nil and callers fall back to words.json.
    private func openBundledReadOnly() {
        guard let url = Bundle.main.url(forResource: "words_v2", withExtension: "db") else {
            Logger.database.error("bundled words_v2.db not found")
            return
        }
        do {
            var config = Configuration()
            config.readonly = true
            setQueue(try DatabaseQueue(path: url.path, configuration: config))
        } catch {
            Logger.database.error("bundled DB open failed: \(error.localizedDescription, privacy: .public)")
            setQueue(nil)
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
