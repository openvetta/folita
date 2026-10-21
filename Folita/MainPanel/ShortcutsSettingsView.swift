import SwiftUI

/// 快捷键设置：可自定义的呼出快捷键，以及面板内的固定按键说明。
struct ShortcutsSettingsView<Recorder: View>: View {
    let recorder: Recorder

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    recorder
                } label: {
                    Text("Show Clipboard Panel")
                }
            } header: {
                Text("Global")
            } footer: {
                Text("Works in any app. Some apps use ⌘⇧V for “Paste and Match Style”; choose another shortcut if it conflicts.")
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(PanelKeyHint.all) { hint in
                    LabeledContent {
                        Text(verbatim: hint.keys)
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundStyle(.secondary)
                    } label: {
                        Text(hint.action)
                    }
                }
            } header: {
                Text("In the Clipboard Panel")
            }
        }
        .formStyle(.grouped)
    }
}

extension ShortcutsSettingsView where Recorder == TogglePanelShortcutRecorder {
    init() {
        self.init(recorder: TogglePanelShortcutRecorder())
    }
}

/// 面板内固定按键的说明，与 `ClipboardPanelCommand.command(for:modifiers:)` 保持一致。
struct PanelKeyHint: Identifiable {
    let keys: String
    let action: LocalizedStringResource
    var id: String { keys }

    static let all: [PanelKeyHint] = [
        PanelKeyHint(keys: "↑ ↓", action: "Select previous or next item"),
        PanelKeyHint(keys: "→", action: "Preview the selected item"),
        PanelKeyHint(keys: "←", action: "Close the preview"),
        PanelKeyHint(keys: "↩", action: "Paste"),
        PanelKeyHint(keys: "⇧↩", action: "Paste as Plain Text"),
        PanelKeyHint(keys: "⌘1 – ⌘9", action: "Paste one of the first nine items"),
        PanelKeyHint(keys: "⌘⌫", action: "Delete"),
        PanelKeyHint(keys: "Esc", action: "Close the panel"),
    ]
}
