import Foundation
import Observation

/// 剪贴历史的保留策略。
@MainActor
@Observable
final class HistorySettings {
    static let limitOptions = [100, 500, 1_000, 5_000]
    static let defaultLimit = 500
    static let limitKey = "FolitaHistoryLimit"

    @ObservationIgnored private let userDefaults: UserDefaults

    var limit: Int {
        didSet { userDefaults.set(limit, forKey: Self.limitKey) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let saved = userDefaults.integer(forKey: Self.limitKey)
        limit = Self.limitOptions.contains(saved) ? saved : Self.defaultLimit
    }
}
