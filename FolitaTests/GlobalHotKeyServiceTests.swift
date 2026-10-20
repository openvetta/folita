import Carbon.HIToolbox
import Testing
@testable import Folita

@MainActor
struct GlobalHotKeyServiceTests {
    /// 只检查常量，不访问 `togglePanel`：它首次访问会写入真实的 UserDefaults。
    @Test func defaultShortcutIsCommandShiftV() {
        let shortcut = GlobalHotKeyService.defaultTogglePanelShortcut
        #expect(shortcut.carbonKeyCode == kVK_ANSI_V)
        #expect(shortcut.modifiers == [.command, .shift])
    }
}
