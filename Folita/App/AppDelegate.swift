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
    /// 测试宿主中不启动 Sparkle。
    let updater = AppEnvironment.isRunningTests ? UpdaterService(backend: nil) : UpdaterService.live()
    /// 剪贴面板是独立于 SwiftUI Scene 的 NSPanel，由 AppDelegate 持有整个生命周期。
    let clipboardPanel: ClipboardPanelController

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
        let historyStore = ClipboardHistoryStore(container: opened.container, limit: { historySettings.limit })
        historySettings.onLimitChange = { historyStore.enforceLimit() }

        self.historySettings = historySettings
        self.privacySettings = privacySettings
        self.historyStore = historyStore
        historyBackupURL = opened.backupURL
        let pasteSettings = PasteSettings()
        let placementSettings = PanelPlacementSettings()
        let pasteService = PasteService(store: historyStore, settings: pasteSettings)
        let clipboardPanel = ClipboardPanelController(
            model: ClipboardPanelModel(store: historyStore),
            placementSettings: placementSettings
        )
        clipboardPanel.model.onPaste = { [weak clipboardPanel] item, mode in
            clipboardPanel?.hide()
            pasteService.paste(item, mode: mode)
        }
        clipboardPanel.model.onRevealInFinder = { [weak clipboardPanel] urls in
            clipboardPanel?.hide()
            NSWorkspace.shared.activateFileViewerSelecting(urls)
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
