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
        // 窗口外观也锁定深色，系统控件、光标与附属气泡与内容一致。
        appearance = NSAppearance(named: .darkAqua)
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        // 面板不带阴影：系统窗口阴影会描出整块透明区域，SwiftUI 阴影的半径加偏移超出窗口边距，会在边缘被裁断。
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
    @ObservationIgnored private let placementSettings: PanelPlacementSettings
    /// 呼出时的鼠标位置与其所在屏幕的可见区域；测试替换为固定值。
    @ObservationIgnored private let pointerProvider: @MainActor () -> PanelPointer?
    @ObservationIgnored let model: ClipboardPanelModel
    @ObservationIgnored private let peekCollapseDelay: Duration
    /// 退出预览后等待收窄动画结束再缩回窗口的任务；测试可等待它完成。
    @ObservationIgnored private(set) var peekCollapse: Task<Void, Never>?

    init(
        model: ClipboardPanelModel,
        placementSettings: PanelPlacementSettings,
        languageSettings: LanguageSettings = .shared,
        pointerProvider: @escaping @MainActor () -> PanelPointer? = { PanelPointer.current },
        peekCollapseDelay: Duration = ClipboardPanelMetrics.peekCollapseDelay
    ) {
        self.model = model
        self.languageSettings = languageSettings
        self.placementSettings = placementSettings
        self.pointerProvider = pointerProvider
        self.peekCollapseDelay = peekCollapseDelay
        model.onDismiss = { [weak self] in self?.hide() }
        model.onPeekChange = { [weak self] in self?.peekChanged($0) }
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        model.prepareForPresentation()
        let panel = panel ?? makePanel()
        cancelPeekCollapse()
        if let pointer = pointerProvider() {
            panel.setFrame(
                ClipboardPanelMetrics.windowFrame(
                    placement: placementSettings.placement,
                    in: pointer.visibleFrame,
                    cursor: pointer.location
                ),
                display: false
            )
        }
        panel.makeKeyAndOrderFront(nil)
        isVisible = true
        installEventMonitors()
    }

    func hide() {
        guard isVisible else { return }
        cancelPeekCollapse()
        closeAttachedWindows()
        panel?.orderOut(nil)
        isVisible = false
        resetPeekWhileHidden()
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
        guard let command = ClipboardPanelCommand.command(for: event),
              command.isIntercepted(isPeeking: model.isPeeking, responder: event.window?.firstResponder ?? panel.firstResponder)
        else { return false }
        model.perform(command)
        return true
    }

    /// 加宽时先放大窗口，容器在其中居中并以动画展开；收窄时反过来，等容器动画收完再缩窗口。
    /// 窗口两侧等量伸缩，容器在屏幕上的位置始终不变。
    private func peekChanged(_ isPeeking: Bool) {
        cancelPeekCollapse()
        guard let panel, panel.isVisible else { return }
        if isPeeking {
            resizePanel(isPeeking: true)
        } else {
            let delay = peekCollapseDelay
            peekCollapse = Task { [weak self] in
                try? await Task.sleep(for: delay)
                guard let self, !Task.isCancelled, !self.model.isPeeking else { return }
                self.resizePanel(isPeeking: false)
            }
        }
    }

    /// 收起时就复位预览并还原窗口尺寸：留到下次呼出再复位，用户会看到从加宽到默认的变形动画。
    private func resetPeekWhileHidden() {
        model.perform(.endPeek)
        resizePanel(isPeeking: false)
    }

    private func cancelPeekCollapse() {
        peekCollapse?.cancel()
        peekCollapse = nil
    }

    private func resizePanel(isPeeking: Bool) {
        guard let panel else { return }
        let frame = ClipboardPanelMetrics.windowFrame(
            resizing: panel.frame,
            isPeeking: isPeeking,
            visibleFrame: panel.screen?.visibleFrame
        )
        panel.setFrame(frame, display: true)
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
            // 铺满窗口并居中：窗口尺寸只由控制器决定。根视图若是固定尺寸，NSHostingView 会在
            // 预览收起时以左下角为基准把窗口缩到内容大小，面板会向左跳，收窄动画也会被裁掉。
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

/// 鼠标指针及其所在屏幕的可见区域。
struct PanelPointer {
    var location: CGPoint
    var visibleFrame: CGRect

    @MainActor
    static var current: PanelPointer? {
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) ?? NSScreen.main else {
            return nil
        }
        return PanelPointer(location: location, visibleFrame: screen.visibleFrame)
    }
}
