import Foundation

/// 预设收藏分组的播种状态（见 docs/adr/0006）。
///
/// 「工作」「生活」只在首次启动写入一次，之后与用户自建的分组完全平等，可删除且不会重建。
/// 因此不能靠「库里没有分组」判断是否该播种——用户删空之后那个条件同样成立。
@MainActor
final class FavoriteSettings {
    static let seededKey = "FolitaFavoriteTabsSeeded"

    @ObservationIgnored private let userDefaults: UserDefaults

    /// 预设分组是否已经播种过一次（含用户后来把它们删掉的情况）。
    var hasSeededDefaultTabs: Bool {
        userDefaults.bool(forKey: Self.seededKey)
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func markDefaultTabsSeeded() {
        userDefaults.set(true, forKey: Self.seededKey)
    }
}
