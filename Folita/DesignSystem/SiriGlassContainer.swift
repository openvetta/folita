import SwiftUI

/// iOS 27 Siri 风格的通透容器：Liquid Glass 打底，自上而下渐隐的着色，
/// 内容在底部淡出，边缘一圈高光，底部带一枚把手。
struct SiriGlassContainer<Content: View>: View {
    var cornerRadius: CGFloat = ClipboardPanelMetrics.cornerRadius
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let style = SiriGlassStyle.resolve(for: colorScheme)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .mask {
                LinearGradient(stops: SiriGlassStyle.contentFade, startPoint: .top, endPoint: .bottom)
            }
            .background {
                LinearGradient(stops: style.tint, startPoint: .top, endPoint: .bottom)
            }
            .clipShape(shape)
            .glassEffect(.clear, in: shape)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: style.rim, startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            }
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(style.handle)
                    .frame(width: 68, height: 5)
                    .padding(.bottom, 10)
            }
    }
}
