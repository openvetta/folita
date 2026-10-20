import KeyboardShortcuts
import SwiftUI

/// 全局快捷键。KeyboardShortcuts 只在这里使用，其他模块不直接依赖它（见 docs/adr/0003）。
@MainActor
final class GlobalHotKeyService {
    /// 默认 ⌘⇧V 呼出剪贴面板，用户可在设置中修改。
    nonisolated static let defaultTogglePanelShortcut = KeyboardShortcuts.Shortcut(.v, modifiers: [.command, .shift])

    /// 首次访问时会把默认值写入 UserDefaults，测试中不要访问。
    nonisolated static let togglePanel = KeyboardShortcuts.Name("toggleClipboardPanel", initial: defaultTogglePanelShortcut)

    private let onTogglePanel: () -> Void
    private var isStarted = false

    init(onTogglePanel: @escaping () -> Void) {
        self.onTogglePanel = onTogglePanel
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        KeyboardShortcuts.onKeyDown(for: Self.togglePanel) { [weak self] in
            self?.onTogglePanel()
        }
    }
}

extension View {
    /// 在菜单项上显示用户当前设置的呼出快捷键。
    func togglePanelShortcutHint() -> some View {
        globalKeyboardShortcut(GlobalHotKeyService.togglePanel)
    }
}

/// 设置页里修改呼出快捷键的录制控件。
struct TogglePanelShortcutRecorder: View {
    var body: some View {
        KeyboardShortcuts.Recorder(for: GlobalHotKeyService.togglePanel)
    }
}
