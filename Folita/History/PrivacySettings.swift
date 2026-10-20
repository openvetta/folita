import Foundation
import Observation

/// 控制哪些复制不被记录。
@MainActor
@Observable
final class PrivacySettings {
    static let pausedKey = "FolitaRecordingPaused"
    static let ignoredAppsKey = "FolitaIgnoredBundleIDs"

    @ObservationIgnored private let userDefaults: UserDefaults

    /// 暂停期间的复制不会被记录，例如屏幕共享时临时关闭。
    var isPaused: Bool {
        didSet { userDefaults.set(isPaused, forKey: Self.pausedKey) }
    }

    /// 从这些应用复制的内容不记录，用于没有标记隐藏内容的密码管理器、网银客户端等。
    var ignoredBundleIDs: [String] {
        didSet { userDefaults.set(ignoredBundleIDs, forKey: Self.ignoredAppsKey) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        isPaused = userDefaults.bool(forKey: Self.pausedKey)
        ignoredBundleIDs = userDefaults.stringArray(forKey: Self.ignoredAppsKey) ?? []
    }

    func ignore(bundleID: String) {
        guard !ignoredBundleIDs.contains(bundleID) else { return }
        ignoredBundleIDs.append(bundleID)
    }

    func unignore(bundleID: String) {
        ignoredBundleIDs.removeAll { $0 == bundleID }
    }
}
