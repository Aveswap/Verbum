import Foundation

struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let points: Int
    let isCurrentUser: Bool
    let badge: BadgeTier?
}

final class LeaderboardStore {
    static let shared = LeaderboardStore()

    // 1 000 deterministic simulated users, sorted descending
    private static let pool: [Int] = {
        var pts: [Int] = []
        // Rank 1-10: elite
        pts += [2850, 2640, 2510, 2380, 2250, 2100, 1980, 1850, 1720, 1600]
        // Rank 11-100: high performers (900 → 1000 range)
        for i in 0..<90  { pts.append(1590 - i * 8) }
        // Rank 101-300: active learners
        for i in 0..<200 { pts.append(889 - i * 3) }
        // Rank 301-700: casual
        for i in 0..<400 { pts.append(289 - (i * 29) / 40) }
        // Rank 701-1000: newcomers
        for i in 0..<300 { pts.append(max(0, 49 - i / 6)) }
        return pts.sorted(by: >)
    }()

    private init() {}

    func rank(for userPoints: Int) -> Int {
        LeaderboardStore.pool.filter { $0 > userPoints }.count + 1
    }

    func badgeTier(for rank: Int) -> BadgeTier? {
        switch rank {
        case ...100:  return .gold
        case ...200:  return .silver
        case ...300:  return .bronze
        default:      return nil
        }
    }

    func totalUsers() -> Int { LeaderboardStore.pool.count + 1 }

    /// Returns entries to display: top 3 + window around the user
    func visibleEntries(userPoints: Int, userName: String) -> [LeaderboardEntry] {
        let userRank = rank(for: userPoints)
        let userBadge = badgeTier(for: userRank)
        let names = LeaderboardStore.names
        var entries: [LeaderboardEntry] = []

        func entry(rank i: Int) -> LeaderboardEntry {
            let idx = i - 1
            let pts = idx < LeaderboardStore.pool.count ? LeaderboardStore.pool[idx] : 0
            let name = names[(idx * 7 + 3) % names.count]
            return LeaderboardEntry(rank: i, name: name, points: pts, isCurrentUser: false, badge: badgeTier(for: i))
        }

        let userEntry = LeaderboardEntry(rank: userRank, name: userName.isEmpty ? "You" : userName, points: userPoints, isCurrentUser: true, badge: userBadge)

        // Top 3 (skip if user is in top 3)
        for i in 1...3 where i != userRank {
            entries.append(entry(rank: i))
        }

        // 2 above user (skip if within top 3)
        if userRank > 4 {
            entries.append(LeaderboardEntry(rank: userRank - 1, name: names[((userRank - 2) * 11) % names.count],
                                            points: LeaderboardStore.pool[userRank - 2], isCurrentUser: false,
                                            badge: badgeTier(for: userRank - 1)))
        }

        entries.append(userEntry)

        // 2 below user
        for i in (userRank + 1)...(userRank + 2) {
            let idx = i - 1
            guard idx < LeaderboardStore.pool.count else { break }
            entries.append(entry(rank: i))
        }

        // Remove dups and sort
        var seen = Set<Int>()
        return entries.filter { seen.insert($0.rank).inserted }.sorted { $0.rank < $1.rank }
    }

    private static let names = [
        "Alex K.", "Maria S.", "James L.", "Emma W.", "Noah B.", "Olivia M.",
        "Liam R.", "Sophia D.", "William T.", "Isabella F.", "Mason G.", "Mia H.",
        "Ethan P.", "Charlotte V.", "Lucas N.", "Amelia C.", "Benjamin A.", "Harper E.",
        "Elijah J.", "Evelyn O.", "Alexander Q.", "Abigail Y.", "Henry U.", "Emily I.",
        "Sebastian Z.", "Elizabeth X.", "Jack W.", "Sofia R.", "Daniel K.", "Avery M.",
        "Logan T.", "Scarlett N.", "Owen F.", "Grace B.", "Lincoln S.", "Chloe A.",
        "Aiden C.", "Penelope D.", "Jackson E.", "Riley G.", "Grayson H.", "Aria J.",
        "Julian L.", "Zoe M.", "Ryan O.", "Nora P.", "Nathan Q.", "Lily R.",
    ]
}
