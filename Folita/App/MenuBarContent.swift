import SwiftUI

struct MenuBarContent: View {
    @Environment(ClipboardPanelController.self) private var clipboardPanel
    @Environment(PrivacySettings.self) private var privacySettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Show Clipboard Panel") {
            clipboardPanel.toggle()
        }
        .togglePanelShortcutHint()

        @Bindable var privacy = privacySettings
        Toggle("Pause Recording", isOn: $privacy.isPaused)

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
