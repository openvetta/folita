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
                .appServices(appDelegate, languageSettings: languageSettings)
        }
        .defaultSize(width: 760, height: 520)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarContent()
                .appServices(appDelegate, languageSettings: languageSettings)
        } label: {
            Image(systemName: "doc.on.clipboard")
        }
    }
}

private extension View {
    /// 主面板与菜单栏共用的服务注入，新增设置对象时只改这里。
    func appServices(_ app: AppDelegate, languageSettings: LanguageSettings) -> some View {
        environment(app.clipboardPanel)
            .environment(app.historyStore)
            .environment(app.historySettings)
            .environment(app.privacySettings)
            .environment(app.pasteSettings)
            .environment(app.placementSettings)
            .environment(app.launchAtLogin)
            .environment(app.appIconSettings)
            .environment(app.updater)
            .environment(languageSettings)
            .environment(\.locale, languageSettings.effectiveLocale)
    }
}
