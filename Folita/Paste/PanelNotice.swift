import AppKit

/// 面板顶部的权限提示。
enum PanelNotice: Hashable {
    case none
    /// 开启了自动粘贴但缺少辅助功能授权，此时只会写回剪贴板。
    case accessibilityNeeded
    /// 系统拒绝了剪贴板访问，新的复制无法被记录。
    case pasteboardDenied

    /// 记录失效比无法自动粘贴更严重，优先提示。
    static func resolve(
        autoPaste: Bool,
        accessibilityTrusted: Bool,
        pasteboardBehavior: NSPasteboard.AccessBehavior
    ) -> PanelNotice {
        if pasteboardBehavior == .alwaysDeny { return .pasteboardDenied }
        if autoPaste && !accessibilityTrusted { return .accessibilityNeeded }
        return .none
    }

    /// 修复入口对应的系统设置页面。
    var settingsURL: URL? {
        switch self {
        case .none: nil
        case .accessibilityNeeded: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .pasteboardDenied: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")
        }
    }
}
