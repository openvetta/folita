import SwiftUI

/// 键帽：圆角描边方格里放一个符号，用来暗示可以按的键，不带文字说明。
/// 组合键拆成多个键帽并排显示（⌥ ↩、⌃ ⇧ X），不要挤在同一格里。
/// 颜色只用语义色，深浅色下都能看清；新增按键提示直接复用，换符号即可。
struct KeyCap: View {
    /// 键帽内容：SF Symbol（如 `arrow.right`）或单个按键字符（如 `⌘`、`K`、`↩`）。
    enum Content: Equatable {
        case symbol(String)
        case character(String)
    }

    let content: Content

    static let size: CGFloat = 22

    init(systemImage: String) {
        content = .symbol(systemImage)
    }

    init(_ character: String) {
        content = .character(character)
    }

    var body: some View {
        label
            .foregroundStyle(.secondary)
            .frame(width: Self.size, height: Self.size)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.secondary.opacity(0.6), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var label: some View {
        switch content {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 11, weight: .semibold))
        case .character(let character):
            Text(verbatim: character)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
