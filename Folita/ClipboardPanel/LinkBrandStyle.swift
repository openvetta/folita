import SwiftUI

/// 链接卡片上站点的样式：右下角徽标与底部色条。YouTube 用系统红，其余用主色，
/// 因此深浅色下都不引入硬编码颜色。
extension LinkTarget.Brand {
    var symbolName: String {
        switch self {
        case .github: "chevron.left.forwardslash.chevron.right"
        case .x: "xmark"
        case .youtube: "play.rectangle.fill"
        }
    }

    var accent: Color {
        switch self {
        case .youtube: .red
        case .github, .x: .primary
        }
    }
}
