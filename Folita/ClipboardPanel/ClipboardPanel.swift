import AppKit
import Observation
import SwiftUI

/// 无边框、透明、不抢占前台应用的浮动面板，作为 Siri 风格玻璃容器的宿主窗口。
final class ClipboardPanel: NSPanel {
    var onCancel: (() -> Void)?

    init() {
        super.init(
            contentRect: CGRect(origin: .zero, size: ClipboardPanelMetrics.windowSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        // 阴影由 SwiftUI 按容器形状绘制，系统窗口阴影会描出整块透明区域。
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

@MainActor
@Observable
final class ClipboardPanelController {
    private(set) var isVisible = false

    @ObservationIgnored private(set) var panel: ClipboardPanel?

    @ObservationIgnored private var eventMonitors: [Any] = []
    @ObservationIgnored private let languageSettings: LanguageSettings
    @ObservationIgnored let model: ClipboardPanelModel

    init(model: ClipboardPanelModel, languageSettings: LanguageSettings = .shared) {
        self.model = model
        self.languageSettings = languageSettings
        model.onDismiss = { [weak self] in self?.hide() }
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        model.prepareForPresentation()
        let panel = panel ?? makePanel()
        if let screen = NSScreen.screenContainingMouse ?? NSScreen.main {
            panel.setFrame(ClipboardPanelMetrics.windowFrame(in: screen.visibleFrame), display: false)
        }
        panel.makeKeyAndOrderFront(nil)
        isVisible = true
        installEventMonitors()
    }

    func hide() {
        guard isVisible else { return }
        closeAttachedWindows()
        panel?.orderOut(nil)
        isVisible = false
        removeEventMonitors()
    }

    /// 面板不是常驻窗口：在本应用内点到面板以外的地方（含菜单栏图标），
    /// 以及在别的应用里点击，都应将其收起。
    private func installEventMonitors() {
        removeEventMonitors()

        let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, let window = self.panel else { return }
                // 事件已经落在面板窗口上，交给视图自己处理。
                guard window.isVisible, event.window !== window else { return }
                self.dismissIfClickIsOutside(NSEvent.mouseLocation)
            }
            return event
        }

        let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.dismissIfClickIsOutside(NSEvent.mouseLocation)
            }
        }

        // 搜索框获得焦点时 TextField 会先处理方向键与 ⌘⌫，视图层的 onKeyPress 收不到，
        // 因此在窗口分发前拦截：属于面板快捷键的按键被消费，其余键照常输入搜索词。
        let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return MainActor.assumeIsolated { self.handleKeyDown(event) } ? nil : event
        }

        eventMonitors = [local, global, keys].compactMap { $0 }
    }

    /// 返回是否已消费该按键；面板收起、按键不属于面板或事件来自其他窗口（如筛选气泡）时返回 false。
    @discardableResult
    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let panel, panel.isVisible else { return false }
        if let window = event.window {
            guard window === panel else { return false }
            // 输入法组字期间方向键属于候选选择，交给输入法处理。
            guard !ClipboardPanelCommand.isComposing(in: window.firstResponder) else { return false }
        }
        guard let command = ClipboardPanelCommand.command(for: event) else { return false }
        model.perform(command)
        return true
    }

    private func removeEventMonitors() {
        eventMonitors.forEach(NSEvent.removeMonitor)
        eventMonitors.removeAll()
    }

    /// 点在外面就收起；点在面板或气泡内部则保持打开。
    private func dismissIfClickIsOutside(_ point: CGPoint) {
        guard let panel, panel.isVisible else { return }
        if ClipboardPanelDismissal.shouldDismiss(
            clickAt: point,
            panelFrame: panel.frame,
            attachedFrames: panel.attachedWindowFrames
        ) {
            hide()
        }
    }

    /// 收起面板时一并关掉仍然打开的气泡，避免下次显示时残留。
    private func closeAttachedWindows() {
        guard let panel else { return }
        panel.attachedWindows.forEach { $0.orderOut(nil) }
    }

    private func makePanel() -> ClipboardPanel {
        let panel = ClipboardPanel()
        let hostingView = NSHostingView(
            rootView: ClipboardPanelHostView(
                model: model,
                languageSettings: languageSettings
            )
        )
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.onCancel = { [weak self] in self?.hide() }
        self.panel = panel
        return panel
    }
}

/// 包裹 ClipboardPanelView 并绑定 LanguageSettings，在切换语言时动态刷新 Locale。
private struct ClipboardPanelHostView: View {
    let model: ClipboardPanelModel
    @Bindable var languageSettings: LanguageSettings

    var body: some View {
        ClipboardPanelView(model: model)
            .environment(languageSettings)
            .environment(\.locale, languageSettings.effectiveLocale)
    }
}

private extension NSWindow {
    /// 面板弹出的气泡等附属窗口（系统 popover 是独立窗口，不是 childWindow）。
    var attachedWindows: [NSWindow] {
        NSApp.windows.filter { window in
            window !== self
                && window.isVisible
                && window.className.localizedCaseInsensitiveContains("popover")
        }
    }

    /// 面板自身与其附属窗口在屏幕上的范围，用于判定“面板外”的点击。
    var attachedWindowFrames: [CGRect] {
        (childWindows ?? []).map(\.frame) + attachedWindows.map(\.frame)
    }
}

private extension NSScreen {
    static var screenContainingMouse: NSScreen? {
        let location = NSEvent.mouseLocation
        return screens.first { $0.frame.contains(location) }
    }
}
