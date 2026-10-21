import SwiftUI

/// 键帽：圆角描边方块里放一个符号，用来暗示可以按的键，不带文字说明。
/// 颜色只用语义色，深浅色下都能看清；新增按键提示直接复用，换符号即可。
struct KeyCap: View {
    /// 键帽内显示的 SF Symbol，例如 `arrow.right`、`return`。
    let systemImage: String

    static let size: CGFloat = 22

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: Self.size, height: Self.size)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.secondary.opacity(0.6), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}
