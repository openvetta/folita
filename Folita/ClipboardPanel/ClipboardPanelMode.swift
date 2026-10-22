import Foundation

/// 剪贴面板的两种视图模式：普通剪贴列表，或收藏夹（见 docs/adr/0006）。
/// 与右上角的类型筛选是两个正交维度：收藏夹里改动 `ClipboardFilter` 只做二次过滤。
enum ClipboardPanelMode: Equatable, Hashable, Sendable {
    case history
    case favorites

    var title: LocalizedStringResource {
        switch self {
        case .history: "Clipboard History"
        case .favorites: "Favorites"
        }
    }

    var symbolName: String {
        switch self {
        case .history: "clock.arrow.circlepath"
        case .favorites: "star.fill"
        }
    }

    /// 换模式时给用户看的按键提示：进入收藏夹与退出收藏夹的键不同，避免同键双向。
    var keyCaps: [String] {
        switch self {
        case .history: ["⌘", "←"]
        case .favorites: []
        }
    }
}
