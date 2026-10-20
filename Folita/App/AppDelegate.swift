import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 剪贴面板是独立于 SwiftUI Scene 的 NSPanel，由 AppDelegate 持有整个生命周期。
    let clipboardPanel = ClipboardPanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // 调试入口：`open Folita.app --args -FolitaShowClipboardPanel YES` 启动即弹出剪贴面板。
        if UserDefaults.standard.bool(forKey: "FolitaShowClipboardPanel") {
            clipboardPanel.show()
        }
        #endif
    }
}
