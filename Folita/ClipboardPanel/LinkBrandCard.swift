import SwiftUI

/// GitHub、X、YouTube 链接在详情里的专属卡片：大标题、网址、右下角站点徽标与底部色条。
/// 只用网址本身绘制，不联网，所以没有简介、头像、统计数。
struct LinkBrandCard: View {
    let target: LinkTarget
    let url: URL

    /// 卡片固定高度：内容只有标题、网址与站点标识，不需要占满整个预览区。
    static let height: CGFloat = 184

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let style = SiriGlassStyle.resolve(for: colorScheme)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(Self.title(of: target))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.middle)
                Text(verbatim: url.absoluteString)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.top, ClipPeekCard.actionButtonsInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(target.kind.title)
                        .font(.system(size: 12, weight: .medium))
                    Text(verbatim: target.brand.name)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: target.brand.symbolName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Rectangle().fill(target.brand.accent).frame(height: 8)
        }
        // 高度含底部色条。
        .frame(height: Self.height)
        .background(style.linkCardBackground, in: shape)
        .clipShape(shape)
        .overlay { shape.strokeBorder(style.iconRim, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }

    /// 仓库显示成「所有者/」细体加「仓库名」粗体，其余整段粗体。
    static func title(of target: LinkTarget) -> AttributedString {
        let bold = Font.system(size: 22, weight: .bold)
        if target.kind == .repository, let slash = target.title.firstIndex(of: "/") {
            var owner = AttributedString(String(target.title[...slash]))
            owner.font = .system(size: 22, weight: .light)
            var name = AttributedString(String(target.title[target.title.index(after: slash)...]))
            name.font = bold
            return owner + name
        }
        var whole = AttributedString(target.title)
        whole.font = bold
        return whole
    }
}
