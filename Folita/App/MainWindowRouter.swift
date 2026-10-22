import AppKit
import SwiftUI

/// 从 AppKit 侧（剪贴面板、AppDelegate）打开 SwiftUI 主面板窗口的入口。
///
/// SwiftUI 的 `openWindow` 只能从挂在场景里的视图取到，而面板与 AppDelegate 都是 AppKit 代码，
/// 由菜单栏标签上的 `WindowOpeningBridge` 在启动时把动作交给这里。
@MainActor
final class MainWindowRouter {
    /// 测试中替换为记录调用，避免真的切换前台应用。
    private let activate: @MainActor () -> Void
    /// 场景挂载前为 nil，此时 `present()` 只做激活，不至于静默无事发生。
    private var openWindow: (@MainActor () -> Void)?

    init(activate: @escaping @MainActor () -> Void = { NSApp.activate() }) {
        self.activate = activate
    }

    func register(_ openWindow: @escaping @MainActor () -> Void) {
        self.openWindow = openWindow
    }

    /// 打开主面板并把它带到前台。
    func present() {
        openWindow?()
        activate()
    }
}

/// 常驻的 SwiftUI 视图：菜单栏标签随应用启动就挂载，用它把 `openWindow` 交给 `MainWindowRouter`。
struct WindowOpeningBridge: View {
    @Environment(\.openWindow) private var openWindow
    let router: MainWindowRouter

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task { router.register { openWindow(id: SceneID.main) } }
    }
}
