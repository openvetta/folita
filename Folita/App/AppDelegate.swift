import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let historySettings: HistorySettings
    let privacySettings: PrivacySettings
    let historyStore: ClipboardHistoryStore
    let pasteSettings: PasteSettings
    let placementSettings: PanelPlacementSettings
    let launchAtLogin = LaunchAtLogin()
    let appIconSettings = AppIconSettings()
    /// 从 AppKit 侧打开 SwiftUI 主面板的入口，动作在启动时由菜单栏标签里的视图注入。
    let mainWindow: MainWindowRouter
    /// 主面板打开时显示程序坞图标，关闭后恢复菜单栏应用的形态。
    let dockIcon = DockIconVisibility()
    /// 测试宿主中不启动 Sparkle。
    let updater = AppEnvironment.isRunningTests ? UpdaterService(backend: nil) : UpdaterService.live()
    /// 剪贴面板是独立于 SwiftUI Scene 的 NSPanel，由 AppDelegate 持有整个生命周期。
    let clipboardPanel: ClipboardPanelController

    /// 预设收藏分组的播种状态（见 docs/adr/0006）。
    let favoriteSettings: FavoriteSettings

    private let clipboardMonitor: ClipboardMonitor
    private let pasteService: PasteService
    private let hotKeys: GlobalHotKeyService
    private let historyBackupURL: URL?

    override init() {
        let historySettings = HistorySettings()
        let privacySettings = PrivacySettings()
        let opened = AppEnvironment.isRunningTests
            ? HistoryStorage.Opened(container: HistoryStorage.makeInMemoryContainer(), backupURL: nil)
            : HistoryStorage.open()
        let favoriteSettings = FavoriteSettings()
        // 预设分组只在首次启动播种一次，名字按当时的界面语言写入。
        let historyStore = ClipboardHistoryStore(
            container: opened.container,
            limit: { historySettings.limit },
            defaultTabNames: ClipboardHistoryStore.defaultTabNames(
                locale: AppEnvironment.isRunningTests ? Locale(identifier: "en") : LanguageSettings.shared.effectiveLocale
            ),
            favoriteSettings: AppEnvironment.isRunningTests ? nil : favoriteSettings
        )
        historySettings.onLimitChange = { historyStore.enforceLimit() }

        self.favoriteSettings = favoriteSettings
        self.historySettings = historySettings
        self.privacySettings = privacySettings
        self.historyStore = historyStore
        historyBackupURL = opened.backupURL
        let pasteSettings = PasteSettings()
        let placementSettings = PanelPlacementSettings()
        let pasteService = PasteService(store: historyStore, settings: pasteSettings)
        let mainWindow = MainWindowRouter()
        let clipboardPanel = ClipboardPanelController(
            model: ClipboardPanelModel(store: historyStore),
            placementSettings: placementSettings
        )
        clipboardPanel.model.onPaste = { [weak clipboardPanel] item, mode in
            clipboardPanel?.hide()
            pasteService.paste(item, mode: mode)
        }
        // ⌥↩：面板不收起，⌘V 直接投递给原来的应用，方便连续粘贴多条。
        clipboardPanel.model.onPasteKeepingPanelOpen = { item, mode in
            pasteService.paste(item, mode: mode, keepingPanelOpen: true)
        }
        clipboardPanel.model.onRevealInFinder = { [weak clipboardPanel] urls in
            clipboardPanel?.hide()
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }
        clipboardPanel.model.onOpenURL = { [weak clipboardPanel] url in
            clipboardPanel?.hide()
            NSWorkspace.shared.open(url)
        }
        clipboardPanel.model.onPasteText = { [weak clipboardPanel] text in
            clipboardPanel?.hide()
            pasteService.paste(text: text)
        }
        // ⌘,：面板里通常是要去改设置，先收起面板再打开主面板。
        clipboardPanel.model.onOpenMainPanel = { [weak clipboardPanel] in
            clipboardPanel?.hide()
            mainWindow.present()
        }
        clipboardPanel.model.noticeProvider = {
            PanelNotice.resolve(
                autoPaste: pasteSettings.autoPaste,
                accessibilityTrusted: AccessibilityAccess.system.isTrusted(),
                pasteboardBehavior: NSPasteboard.general.accessBehavior
            )
        }
        clipboardPanel.model.onResolveNotice = { [weak clipboardPanel] notice in
            clipboardPanel?.hide()
            // 先请求一次授权，系统会把应用加入授权列表，用户只需打开开关。
            if notice == .accessibilityNeeded {
                AccessibilityAccess.system.requestAccess()
            }
            if let url = notice.settingsURL {
                NSWorkspace.shared.open(url)
            }
        }

        self.pasteSettings = pasteSettings
        self.placementSettings = placementSettings
        self.pasteService = pasteService
        self.mainWindow = mainWindow
        self.clipboardPanel = clipboardPanel
        hotKeys = GlobalHotKeyService { [weak clipboardPanel] in clipboardPanel?.toggle() }
        clipboardMonitor = ClipboardMonitor(privacy: privacySettings) { historyStore.record($0) }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isRunningTests else { return }
        appIconSettings.apply()
        clipboardMonitor.start()
        hotKeys.start()
        if let historyBackupURL {
            presentHistoryRecoveredAlert(backupURL: historyBackupURL)
        }

        #if DEBUG
        // 调试入口：`open Folita.app --args -FolitaShowClipboardPanel YES` 启动即弹出剪贴面板。
        if UserDefaults.standard.bool(forKey: "FolitaShowClipboardPanel") {
            clipboardPanel.show()
        }
        #endif
    }

    private func presentHistoryRecoveredAlert(backupURL: URL) {
        let locale = LanguageSettings.shared.effectiveLocale
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "Clipboard history could not be opened", locale: locale)
        alert.informativeText = String(
            localized: "Folita started a new history. The previous data was moved to \(backupURL.path(percentEncoded: false)).",
            locale: locale
        )
        NSApp.activate()
        alert.runModal()
    }
}
