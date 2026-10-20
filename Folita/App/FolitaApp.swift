import SwiftUI

enum SceneID {
    static let main = "main"
}

@main
struct FolitaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 主面板：传统 macOS 工具类的侧边栏 + 设置内容布局。
        Window(Text(verbatim: "Folita"), id: SceneID.main) {
            MainPanelView()
                .environment(appDelegate.clipboardPanel)
        }
        .defaultSize(width: 760, height: 520)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarContent()
                .environment(appDelegate.clipboardPanel)
        } label: {
            Image(systemName: "doc.on.clipboard")
        }
    }
}
