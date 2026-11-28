import Foundation
import SwiftData

/// A medal the user has earned (§4.1). One row per medal: tiers upgrade the same row.
@Model
final class EarnedMedal {
    var medalId: String = ""
    /// Raw value of the highest tier earned.
    var tierLevel: String = MedalTierLevel.bronze.rawValue
    /// When the first tier's condition was first met (from visit dates).
    var earnedAt: Date = Date.distantPast
    /// Awarded by the §4.4 backfill pass over existing history.
    var isRetroactive: Bool = false
    /// When the user was shown the current tier; nil = unseen (drives the "new medal" sheet).
    var surfacedAt: Date?
    var catalogVersion: Int = 1
    /// Place (or other evidence) that crossed the first tier.
    var triggerName: String?
    /// JSON-encoded `[EarnedMedalTier]`, lowest tier first.
    var tierHistoryData: Data?
    var lastModifiedAt: Date = Date()

    init(medalId: String, tierLevel: String, earnedAt: Date, isRetroactive: Bool, catalogVersion: Int, triggerName: String?) {
        self.medalId = medalId
        self.tierLevel = tierLevel
        self.earnedAt = earnedAt
        self.isRetroactive = isRetroactive
        self.catalogVersion = catalogVersion
        self.triggerName = triggerName
    }

    var tierHistory: [EarnedMedalTier] {
        get { tierHistoryData.flatMap { try? JSONDecoder().decode([EarnedMedalTier].self, from: $0) } ?? [] }
        set { tierHistoryData = try? JSONEncoder().encode(newValue) }
    }

    var tier: MedalTierLevel { MedalTierLevel(rawValue: tierLevel) ?? .bronze }
}

struct EarnedMedalTier: Codable, Equatable, Sendable {
    let level: String
    var earnedAt: Date
    var trigger: String
    /// Granted from a v1 badge the user already had (§4.4 step 3).
    var isLegacy: Bool = false
}
