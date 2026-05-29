import Foundation

/// FSRS-5 spaced repetition scheduler.
/// Reference: https://github.com/open-spaced-repetition/fsrs.js (algorithm v5).
/// We adapted it to be ratings 1...4 (again / hard / good / easy) and a desired
/// retention of 0.9 (the user resurfaces a word when its recall probability ≈ 90 %).
enum FSRSRating: Int { case again = 1, hard = 2, good = 3, easy = 4 }

enum FSRS {
    /// FSRS-5 default weights, published in the official repo.
    /// 17-element vector. Do not reorder — index positions are load-bearing.
    static let w: [Double] = [
        0.4072, 1.1829, 3.1262, 15.4722,
        7.2102, 0.5316, 1.0651, 0.0234,
        1.616, 0.1544, 1.0824, 1.9813,
        0.0953, 0.2975, 2.2042, 0.2407,
        2.9466
    ]

    /// Target retention probability when the card becomes due (90% recall chance).
    static let targetRetention: Double = 0.9

    /// Factor that maps stability to the desired-retention interval.
    /// Derived from the FSRS forgetting curve constant.
    static let decay: Double = -0.5
    static let factor: Double = pow(0.9, 1.0 / decay) - 1.0  // ≈ 19/81

    /// Returns the next review state after the user rates a card.
    static func next(_ review: WordReview, rating: FSRSRating, now: Date = Date()) -> WordReview {
        var r = review
        // Time since last review (in days). For brand-new cards this is 0.
        let elapsed: Double
        if let last = r.lastReview {
            elapsed = max(0, now.timeIntervalSince(last) / 86400.0)
        } else {
            elapsed = 0
        }
        r.elapsedDays = elapsed

        if r.state == .new {
            // First review — bootstrap stability + difficulty from the rating.
            r.difficulty = initialDifficulty(rating)
            r.stability = initialStability(rating)
            r.reps = 1
            if rating == .again {
                r.state = .learning
            } else {
                r.state = .review
            }
        } else {
            // Subsequent reviews — apply FSRS-5 update rules.
            let retrievability = recallProbability(stability: r.stability, elapsedDays: elapsed)
            if rating == .again {
                r.stability = nextLapseStability(d: r.difficulty,
                                                 s: r.stability,
                                                 r: retrievability)
                r.lapses += 1
                r.state = .relearning
            } else {
                r.stability = nextSuccessStability(d: r.difficulty,
                                                   s: r.stability,
                                                   r: retrievability,
                                                   rating: rating)
                r.reps += 1
                r.state = .review
            }
            r.difficulty = nextDifficulty(d: r.difficulty, rating: rating)
        }

        // Schedule next due date based on stability + target retention.
        // I(r) = (S / factor) * (r^(1/decay) - 1)
        let interval: Double
        if rating == .again {
            interval = max(1.0, r.stability * 0.5)   // short rest after a lapse
        } else {
            let raw = r.stability * (pow(targetRetention, 1.0 / decay) - 1.0) / factor
            interval = max(1.0, raw)
        }
        r.scheduledDays = interval
        r.dueDate = now.addingTimeInterval(interval * 86400.0)
        r.lastReview = now
        return r
    }

    // MARK: - Internal

    private static func initialDifficulty(_ rating: FSRSRating) -> Double {
        // D_0 = w[4] - exp(w[5] * (rating-1)) + 1, clamped to 1...10
        let raw = w[4] - exp(w[5] * Double(rating.rawValue - 1)) + 1.0
        return clamp(raw, 1.0, 10.0)
    }

    private static func initialStability(_ rating: FSRSRating) -> Double {
        let s = w[rating.rawValue - 1]
        return max(0.1, s)
    }

    private static func recallProbability(stability: Double, elapsedDays: Double) -> Double {
        guard stability > 0 else { return 0 }
        // R = (1 + factor * t/S)^decay
        return pow(1.0 + factor * elapsedDays / stability, decay)
    }

    private static func nextDifficulty(d: Double, rating: FSRSRating) -> Double {
        // FSRS-5: delta = -w[6]*(rating-3); apply linear damping delta*(10-D)/9 so high
        // difficulties move less, then mean-revert toward D0(easy) — i.e. D0(4), not D0(good).
        let delta = -w[6] * Double(rating.rawValue - 3)
        let damped = d + delta * (10.0 - d) / 9.0
        let target = initialDifficulty(.easy)
        let nd = w[7] * target + (1 - w[7]) * damped
        return clamp(nd, 1.0, 10.0)
    }

    private static func nextSuccessStability(d: Double, s: Double, r: Double, rating: FSRSRating) -> Double {
        // S' = S * (1 + exp(w[8]) * (11 - D) * S^(-w[9]) * (exp((1-R)*w[10]) - 1) * hard_pen * easy_bonus)
        let hardPenalty = rating == .hard ? w[15] : 1.0
        let easyBonus   = rating == .easy ? w[16] : 1.0
        let factorTerm  = exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp((1 - r) * w[10]) - 1) * hardPenalty * easyBonus
        return max(0.1, s * (1 + factorTerm))
    }

    private static func nextLapseStability(d: Double, s: Double, r: Double) -> Double {
        // S_lapse = w[11] * D^(-w[12]) * ((S+1)^w[13] - 1) * exp(w[14] * (1-R))
        let raw = w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp(w[14] * (1 - r))
        return max(0.1, raw)
    }

    private static func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(x, lo), hi)
    }
}
