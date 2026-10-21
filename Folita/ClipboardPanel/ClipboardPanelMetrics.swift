import CoreGraphics

enum ClipboardPanelMetrics {
    /// 玻璃容器本体尺寸。
    static let containerSize = CGSize(width: 440, height: 560)
    static let cornerRadius: CGFloat = 34
    /// 顶栏圆形按钮与搜索胶囊的高度。
    static let controlHeight: CGFloat = 30
    static let searchFieldWidth: CGFloat = 220
    /// 历史行的统一高度：两行文字加上下留白，选中不改变高度，列表不会跳动。
    static let historyRowHeight: CGFloat = 52
    /// 历史行左侧图标块的边长，图片缩略图也撑满这块区域。
    static let historyIconSize: CGFloat = 28
    static let historyRowCornerRadius: CGFloat = 12
    /// 窗口四周为 SwiftUI 阴影预留的透明边距。
    static let shadowInset: CGFloat = 28
    /// 容器顶边距离屏幕可见区域顶部（菜单栏下沿）的距离。
    static let topSpacing: CGFloat = 8

    static var windowSize: CGSize {
        CGSize(
            width: containerSize.width + shadowInset * 2,
            height: containerSize.height + shadowInset * 2
        )
    }

    /// 面板贴近屏幕顶部居中弹出，与 Siri 自顶部展开的位置一致。
    static func windowFrame(in visibleFrame: CGRect) -> CGRect {
        let size = windowSize
        return CGRect(
            x: (visibleFrame.midX - size.width / 2).rounded(),
            y: visibleFrame.maxY - topSpacing - containerSize.height - shadowInset,
            width: size.width,
            height: size.height
        )
    }
}
