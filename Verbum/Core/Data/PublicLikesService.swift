import Foundation

/// Cross-user "likes" — how many OTHER people loved a word. Dormant by default (no-op); the real
/// CloudKit public-database implementation links in only under the `VERBUM_BACKEND` flag.
protocol PublicLikesService: Sendable {
    /// Record that the current user likes a word (idempotent — one like per user per word).
    func like(wordID: UUID)
    /// Total number of users who liked a word (nil = backend off / unavailable).
    func likeCount(wordID: UUID) async -> Int?
}

/// Dormant default — no cross-user likes. Always compiled.
struct NoLikesService: PublicLikesService {
    func like(wordID: UUID) {}
    func likeCount(wordID: UUID) async -> Int? { nil }
}

enum PublicLikes {
    static let service: PublicLikesService = {
        #if VERBUM_BACKEND
        return CloudKitLikesService()
        #else
        return NoLikesService()
        #endif
    }()
}

#if VERBUM_BACKEND
import CloudKit

/// CloudKit public-DB likes. Each like is one record (deterministic id → idempotent per user).
/// Counting via fetch is fine at small scale; cache or use a counter record if it grows.
/// Requires: iCloud container + a public "WordLike" record type with a queryable `wordID` field.
/// Verify API details on first real build.
struct CloudKitLikesService: PublicLikesService {
    private var db: CKDatabase { CKContainer.default().publicCloudDatabase }

    func like(wordID: UUID) {
        Task {
            guard let uid = try? await CKContainer.default().userRecordID() else { return }
            let name = "\(wordID.uuidString)_\(uid.recordName)"
            let record = CKRecord(recordType: Backend.likeRecordType,
                                  recordID: CKRecord.ID(recordName: name))
            record["wordID"] = wordID.uuidString as CKRecordValue
            _ = try? await db.save(record)
        }
    }

    func likeCount(wordID: UUID) async -> Int? {
        let query = CKQuery(recordType: Backend.likeRecordType,
                            predicate: NSPredicate(format: "wordID == %@", wordID.uuidString))
        guard let result = try? await db.records(matching: query, resultsLimit: 1000) else { return nil }
        return result.matchResults.count
    }
}
#endif
