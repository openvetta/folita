import SwiftUI

struct MenuBarContent: View {
    /// 由 `FolitaApp` 传入：菜单里的「打开主面板」与面板里的 ⌘, 走同一条路径。
    let mainWindow: MainWindowRouter
    @Environment(ClipboardPanelController.self) private var clipboardPanel
    @Environment(UpdaterService.self) private var updater

    var body: some View {
        Button("Show Clipboard Panel") {
            clipboardPanel.toggle()
        }
        .togglePanelShortcutHint()

        Button("Open Main Panel") {
            mainWindow.present()
        }
        .keyboardShortcut(",")

        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!updater.isConfigured)

        Divider()

        Button("Quit Folita") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

/// 菜单栏图标：跟随通用设置里所选的应用图标，彩色（非模板）渲染。
struct MenuBarIcon: View {
    /// 菜单栏图标的标准尺寸；剪贴面板与设置页不改用这个值。
    static let size = AppIconOption.menuBarSide

    /// 菜单栏标签不经过主面板那套 environment 注入，所以设置直接由构造参数传入。
    let appIconSettings: AppIconSettings

    var body: some View {
        icon(for: appIconSettings.selection)
            .frame(width: Self.size, height: Self.size)
            .accessibilityLabel(Text(verbatim: "Folita"))
    }

    @ViewBuilder
    private func icon(for option: AppIconOption) -> some View {
        if let image = option.menuBarImage {
            // 图标在绘制时已缩到菜单栏尺寸，不再拉伸：菜单栏标签按图片自身尺寸布局。
            Image(nsImage: image)
                .interpolation(.high)
        } else {
            // 图标资源缺失时退回剪贴板符号，菜单栏仍保住一个可点的入口。
            Image(systemName: "doc.on.clipboard")
        }
    }
}
