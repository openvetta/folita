import SwiftUI

struct MenuBarContent: View {
    @Environment(ClipboardPanelController.self) private var clipboardPanel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Show Clipboard Panel") {
            clipboardPanel.toggle()
        }
        .togglePanelShortcutHint()

        Button("Open Main Panel") {
            openWindow(id: SceneID.main)
            NSApp.activate()
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Folita") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
