import SwiftUI

/// iOS 27 Siri 风格的通透容器：Liquid Glass 打底，自上而下渐隐的着色，
/// 内容在底部淡出，边缘一圈高光，顶部居中带一枚可拖动的把手。
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
            .overlay(alignment: .top) {
                // 顶部居中的把手暗示这里可以拖动；命中区比可见的胶囊大，更容易抓住。
                Capsule()
                    .fill(style.handle)
                    .frame(width: 36, height: 4)
                    .frame(width: 96, height: 16)
                    .contentShape(.rect)
                    .gesture(WindowDragGesture())
            }
            .background { edgeShadow(in: shape, color: style.shadow) }
    }

    /// 只在容器外侧画投影：玻璃底部近乎透明，整块带阴影会透出一块灰色。
    /// 半径与偏移之和须小于窗口的透明边距，否则会在窗口边缘被裁断。
    private func edgeShadow(in shape: RoundedRectangle, color: Color) -> some View {
        shape
            .fill(.black)
            .shadow(color: color, radius: 12, y: 4)
            .mask {
                Rectangle()
                    .padding(-ClipboardPanelMetrics.shadowInset)
                    .overlay { shape.blendMode(.destinationOut) }
                    .compositingGroup()
            }
    }
}
