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

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        let panel = panel ?? makePanel()
        if let screen = NSScreen.screenContainingMouse ?? NSScreen.main {
            panel.setFrame(ClipboardPanelMetrics.windowFrame(in: screen.visibleFrame), display: false)
        }
        panel.makeKeyAndOrderFront(nil)
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    private func makePanel() -> ClipboardPanel {
        let panel = ClipboardPanel()
        let hostingView = NSHostingView(
            rootView: ClipboardPanelView(onClose: { [weak self] in self?.hide() })
        )
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.onCancel = { [weak self] in self?.hide() }
        self.panel = panel
        return panel
    }
}

private extension NSScreen {
    static var screenContainingMouse: NSScreen? {
        let location = NSEvent.mouseLocation
        return screens.first { $0.frame.contains(location) }
    }
}
