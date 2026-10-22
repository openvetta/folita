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
        // 应用没有 Dock 图标，入口是菜单栏：启动（含登录时启动）不弹主面板，也不恢复上次的窗口。
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        MenuBarExtra {
            MenuBarContent(mainWindow: appDelegate.mainWindow)
                .appServices(appDelegate, languageSettings: languageSettings)
        } label: {
            MenuBarIcon(appIconSettings: appDelegate.appIconSettings)
                // 菜单栏标签是启动后唯一常驻的 SwiftUI 视图，主面板的打开动作从这里取。
                .background(WindowOpeningBridge(router: appDelegate.mainWindow))
        }
    }
}

private extension View {
    /// 主面板与菜单栏共用的服务注入，新增设置对象时只改这里。
    func appServices(_ app: AppDelegate, languageSettings: LanguageSettings) -> some View {
        environment(app.clipboardPanel)
            .environment(app.dockIcon)
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
