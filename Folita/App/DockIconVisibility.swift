import AppKit
import Observation

/// 主面板窗口的程序坞图标。
///
/// 应用以 `LSUIElement` 常驻菜单栏，平时没有程序坞图标；主面板打开时切回常规应用，
/// 关闭后恢复「只常驻菜单栏」，避免菜单栏工具在程序坞和 ⌘Tab 里占位。
@MainActor
@Observable
final class DockIconVisibility {
    @ObservationIgnored private let setPolicy: @MainActor (NSApplication.ActivationPolicy) -> Void
    @ObservationIgnored private var isShown = false

    init(setPolicy: @escaping @MainActor (NSApplication.ActivationPolicy) -> Void = { NSApp.setActivationPolicy($0) }) {
        self.setPolicy = setPolicy
    }

    /// 主面板出现：显示程序坞图标。重复调用不会重复设置激活策略。
    func mainPanelDidAppear() {
        guard !isShown else { return }
        isShown = true
        setPolicy(.regular)
    }

    /// 主面板关闭：恢复无程序坞图标的菜单栏应用。
    func mainPanelDidDisappear() {
        guard isShown else { return }
        isShown = false
        setPolicy(.accessory)
    }
}
