import CoreGraphics

enum ClipboardPanelMetrics {
    /// 玻璃容器本体尺寸。
    static let containerSize = CGSize(width: 440, height: 560)
    static let cornerRadius: CGFloat = 34
    /// 顶栏高度，也是应用图标与筛选按钮的边长。
    static let controlHeight: CGFloat = 36
    /// 历史行的统一高度：两行文字加上下留白，选中不改变高度，列表不会跳动。
    static let historyRowHeight: CGFloat = 52
    /// 历史行左侧图标块的边长，图片缩略图也撑满这块区域。
    static let historyIconSize: CGFloat = 28
    /// 历史列表底部的安全高度：等于容器渐隐区的高度（560 × 30%），高度靠
    /// `SiriGlassStyle.contentFadeStart` 对齐，内容不会被淡出效果吃掉。
    static let listBottomSafeSpace: CGFloat = 168
    static let historyRowCornerRadius: CGFloat = 12
    static let historyRowSpacing: CGFloat = 4
    /// 容器内容的左右留白与顶部留白。
    static let contentInset: CGFloat = 24
    static let contentTopInset: CGFloat = 16
    /// 详情预览（peek）时容器加宽的倍数；左侧列表占 1/3，右侧详情占 2/3。
    static let peekWidthScale: CGFloat = 1.5
    static let peekListFraction: CGFloat = 1.0 / 3
    /// 两栏之间的间距（分割线居中其中）、详情栏与顶栏的间距、详情栏底边到容器底边的距离。
    static let peekColumnGap: CGFloat = 32
    static let peekDetailTopGap: CGFloat = 14
    static let peekDetailBottomInset: CGFloat = 26
    /// 加宽 / 收窄动画的时长；窗口在收窄动画结束后再缩回，避免裁掉还没收完的容器。
    static let peekAnimationDuration: Double = 0.36
    static let peekCollapseDelay: Duration = .milliseconds(420)
    /// 窗口四周的透明边距，容器在窗口内缩进这一圈，预览伸缩时也用它吸收取整误差。
    static let shadowInset: CGFloat = 28
    /// 容器顶边距离屏幕可见区域顶部（菜单栏下沿）的距离。
    static let topSpacing: CGFloat = 8
    /// 光标位置呼出时，容器顶边高出光标的距离，让光标落在容器内部靠近左上角处。
    static let cursorOffset: CGFloat = 12

    static var windowSize: CGSize { windowSize(isPeeking: false) }

    static func containerSize(isPeeking: Bool) -> CGSize {
        guard isPeeking else { return containerSize }
        return CGSize(width: (containerSize.width * peekWidthScale).rounded(), height: containerSize.height)
    }

    static func windowSize(isPeeking: Bool) -> CGSize {
        let container = containerSize(isPeeking: isPeeking)
        return CGSize(width: container.width + shadowInset * 2, height: container.height + shadowInset * 2)
    }

    /// 左侧列表列（含左边距）的宽度：预览时为容器的 1/3，否则占满。
    static func listColumnWidth(isPeeking: Bool) -> CGFloat {
        let container = containerSize(isPeeking: isPeeking)
        guard isPeeking else { return container.width - contentInset * 2 }
        return (container.width * peekListFraction).rounded() - contentInset - peekColumnGap / 2
    }

    /// 两栏分割线的横坐标：容器宽度的 1/3 处。
    static func peekDividerX(in container: CGSize) -> CGFloat {
        (container.width * peekListFraction).rounded()
    }

    /// 右侧详情栏在加宽后容器内的位置：占右侧 2/3，顶边在顶栏下方，右边与搜索框对齐。
    static func peekDetailFrame(in container: CGSize) -> CGRect {
        let minX = peekDividerX(in: container) + peekColumnGap / 2
        let minY = contentTopInset + controlHeight + peekDetailTopGap
        return CGRect(
            x: minX,
            y: minY,
            width: container.width - contentInset - minX,
            height: container.height - peekDetailBottomInset - minY
        )
    }

    /// 进入或退出预览时的窗口位置：保持顶边与水平中心不动，向两侧等量伸缩，
    /// 容器在屏幕上的位置不跳；贴近屏幕边缘时向内挪，不让加宽的部分跑出屏幕。
    static func windowFrame(resizing frame: CGRect, isPeeking: Bool, visibleFrame: CGRect?) -> CGRect {
        let size = windowSize(isPeeking: isPeeking)
        var x = (frame.midX - size.width / 2).rounded()
        if let visibleFrame {
            x = min(max(x, visibleFrame.minX - shadowInset), visibleFrame.maxX + shadowInset - size.width)
        }
        return CGRect(x: x, y: frame.maxY - size.height, width: size.width, height: size.height)
    }

    /// 按用户选择的位置呼出；`cursor` 是鼠标指针的屏幕坐标。
    static func windowFrame(placement: PanelPlacement, in visibleFrame: CGRect, cursor: CGPoint) -> CGRect {
        switch placement {
        case .topCenter:
            return windowFrame(in: visibleFrame)
        case .center:
            let size = windowSize
            return CGRect(
                x: (visibleFrame.midX - size.width / 2).rounded(),
                y: (visibleFrame.midY - size.height / 2).rounded(),
                width: size.width,
                height: size.height
            )
        case .cursor:
            // 容器左上角略高于光标、与光标左对齐；贴近屏幕边缘时整体向内挪，阴影边距允许伸出屏幕。
            let size = windowSize
            let x = min(
                max(cursor.x - shadowInset, visibleFrame.minX - shadowInset),
                visibleFrame.maxX + shadowInset - size.width
            )
            let y = min(
                max(cursor.y + cursorOffset + shadowInset - size.height, visibleFrame.minY - shadowInset),
                visibleFrame.maxY + shadowInset - size.height
            )
            return CGRect(x: x.rounded(), y: y.rounded(), width: size.width, height: size.height)
        }
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
