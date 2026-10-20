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
    /// 调小上限后由存储立即淘汰多出的记录，而不是等下一次复制。
    @ObservationIgnored var onLimitChange: () -> Void = {}

    var limit: Int {
        didSet {
            userDefaults.set(limit, forKey: Self.limitKey)
            onLimitChange()
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let saved = userDefaults.integer(forKey: Self.limitKey)
        limit = Self.limitOptions.contains(saved) ? saved : Self.defaultLimit
    }
}
