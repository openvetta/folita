import AppKit
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct ShortcutsSettingsTests {
    /// 说明文字与实际按键映射必须一致。
    @Test func keyHintsMatchPanelCommands() {
        typealias C = ClipboardPanelCommand
        #expect(C.command(for: .upArrow, modifiers: []) == .moveUp)
        #expect(C.command(for: .return, modifiers: []) == .paste(.original))
        #expect(C.command(for: .return, modifiers: .shift) == .paste(.plainText))
        #expect(C.command(for: "1", modifiers: .command) == .pasteAt(0))
        #expect(C.command(for: "9", modifiers: .command) == .pasteAt(8))
        #expect(C.command(for: .delete, modifiers: .command) == .deleteSelected)
        #expect(C.command(for: .return, modifiers: .option) == .pasteKeepingPanelOpen)
        #expect(C.command(for: "x", modifiers: .control) == .deleteSelected)
        #expect(C.command(for: "x", modifiers: [.control, .shift]) == .deleteAll)
        #expect(C.command(for: "k", modifiers: .command) == .toggleActionsMenu)
        #expect(C.command(for: .escape, modifiers: []) == .dismiss)
        #expect(C.command(for: .rightArrow, modifiers: []) == .peek)
        #expect(C.command(for: .leftArrow, modifiers: []) == .endPeek)
        #expect(C.command(for: .leftArrow, modifiers: .command) == .toggleFavorites)
        #expect(C.command(for: "f", modifiers: .command) == .toggleFavoritePicker)
        #expect(PanelKeyHint.all.map(\.keys) == [
            "↑ ↓", "→", "←", "⌘←", "⌘F", "↩", "⇧↩", "⌥↩", "⌘1 – ⌘9",
            "⌘K", "⌘⌫", "⌃X", "⌃⇧X", "Esc",
        ])
    }

    @Test(arguments: [
        ("zh-Hans", ColorScheme.light), ("zh-Hans", .dark), ("en", .light), ("en", .dark),
    ])
    func laysOut(locale: String, scheme: ColorScheme) {
        // 用占位视图代替真实录制控件：后者首次渲染会把默认快捷键写入真实 UserDefaults。
        let view = ShortcutsSettingsView(recorder: Text(verbatim: "⌘⇧V"))
            .environment(\.locale, Locale(identifier: locale))
            .environment(\.colorScheme, scheme)
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(x: 0, y: 0, width: 520, height: 520)
        host.layoutSubtreeIfNeeded()
        #expect(host.frame.width == 520)
    }
}
