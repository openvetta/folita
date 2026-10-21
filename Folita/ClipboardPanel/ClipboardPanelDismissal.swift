import CoreGraphics

/// 判断面板外点击是否应当关闭面板。抽成纯函数，便于对边界情况直接测试。
enum ClipboardPanelDismissal {
    /// - Parameters:
    ///   - point: 全局屏幕坐标（原点在主屏左下角）中的点击位置。
    ///   - panelFrame: 面板窗口自身的位置与大小，含四周的透明边距。
    ///   - attachedFrames: 面板的附属窗口，例如筛选气泡，点击它们不应关闭面板。
    static func shouldDismiss(
        clickAt point: CGPoint,
        panelFrame: CGRect,
        attachedFrames: [CGRect]
    ) -> Bool {
        if panelFrame.contains(point) { return false }
        return !attachedFrames.contains { $0.contains(point) }
    }
}
