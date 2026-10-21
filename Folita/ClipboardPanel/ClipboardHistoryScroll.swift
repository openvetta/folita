import SwiftUI

/// 列表滚动时用到的几何信息：当前偏移与可见区域高度。
struct ListGeometry: Equatable {
    var offset: CGFloat = 0
    /// 可见区域高度；首帧尚未布局时为 0。
    var viewportHeight: CGFloat = 0
}

/// 历史列表的滚动位置计算。
///
/// 容器底部有一段渐隐蒙版，落在里面的内容会被淡出。滚动位置不交给 `scrollTo` 的锚点：
/// 它只保证目标“可见”，而渐隐区在布局上仍是可见区域。这里按固定行高算出精确偏移，
/// 让选中行整行停在渐隐区上方，并且只做必要的滚动，不打扰用户手动滚到的位置。
enum ClipboardHistoryScroll {
    /// 选中行需要停靠的位置。返回与 `currentOffset` 相同的值表示不需要滚动。
    static func targetOffset(
        selectedIndex: Int,
        itemCount: Int,
        viewportHeight: CGFloat,
        currentOffset: CGFloat
    ) -> CGFloat {
        guard itemCount > 0, viewportHeight > 0, selectedIndex >= 0, selectedIndex < itemCount else {
            return currentOffset
        }

        let rowHeight = ClipboardPanelMetrics.historyRowHeight
        let spacing = ClipboardPanelMetrics.historyRowSpacing
        let safeSpace = ClipboardPanelMetrics.listBottomSafeSpace

        let rowTop = CGFloat(selectedIndex) * (rowHeight + spacing)
        let rowBottom = rowTop + rowHeight
        // 底部安全区同样占用内容高度，最后几行才能滚到渐隐区上方。
        let contentHeight = CGFloat(itemCount) * rowHeight + CGFloat(itemCount - 1) * spacing + safeSpace
        let maxOffset = max(0, contentHeight - viewportHeight)
        // 视口内允许放置内容的区域下沿，再往下就会落进渐隐区。
        let contentBottom = viewportHeight - safeSpace

        let target: CGFloat
        if rowBottom > contentBottom + currentOffset {
            target = rowBottom - contentBottom
        } else if rowTop < currentOffset {
            target = rowTop
        } else {
            return currentOffset
        }
        return min(max(target, 0), maxOffset)
    }
}
