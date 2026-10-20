import SwiftUI

enum SceneID {
    static let main = "main"
}

@main
struct FolitaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var languageSettings = LanguageSettings.shared

    var body: some Scene {
        // 主面板：传统 macOS 工具类的侧边栏 + 设置内容布局。
        Window(Text(verbatim: "Folita"), id: SceneID.main) {
            MainPanelView()
                .environment(appDelegate.clipboardPanel)
                .environment(languageSettings)
                .environment(\.locale, languageSettings.effectiveLocale)
        }
        .defaultSize(width: 760, height: 520)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarContent()
                .environment(appDelegate.clipboardPanel)
                .environment(languageSettings)
                .environment(\.locale, languageSettings.effectiveLocale)
        } label: {
            Image(systemName: "doc.on.clipboard")
        }
    }
}
