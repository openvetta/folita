import SwiftUI

/// Siri 新 UI 质地的取色：上部高不透明度着色承载文字，下部渐隐露出底层玻璃，
/// 再以一圈高光描边勾出容器边缘。深浅色外观各自一套，禁止在视图中硬编码颜色。
struct SiriGlassStyle: Equatable {
    var tint: [Gradient.Stop]
    var rim: [Color]
    var handle: Color
    /// 选中行的底色：近乎实心，列表落到容器下部的渐隐区时也不会透出桌面。
    var selection: Color
    /// 选中行的描边，给实心底色勾出边缘。
    var selectionRim: Color
    /// 历史行左侧图标块的底色与字形颜色：实心块让图标在任何壁纸上都看得清。
    var iconBackground: Color
    var iconForeground: Color
    var iconRim: Color
    /// 详情预览：两栏之间的分割线、预览区与信息行的衬底、大图投影。
    var peekDivider: Color
    var peekWell: Color
    var peekStripe: Color
    var peekShadow: Color

    /// 内容在容器底部开始渐隐的位置（从容器顶部按比例计）。列表用它在底部留出安全空间。
    static let contentFadeStart: CGFloat = 0.70

    /// 内容在容器底部渐隐的蒙版，与着色渐隐的节奏保持一致。
    static let contentFade: [Gradient.Stop] = [
        .init(color: .black, location: 0),
        .init(color: .black, location: contentFadeStart),
        .init(color: .clear, location: 0.94),
    ]

    static func resolve(for colorScheme: ColorScheme) -> SiriGlassStyle {
        switch colorScheme {
        case .light:
            SiriGlassStyle(
                tint: [
                    .init(color: .white.opacity(0.94), location: 0),
                    .init(color: .white.opacity(0.88), location: 0.55),
                    .init(color: .white.opacity(0.40), location: 0.84),
                    .init(color: .white.opacity(0.08), location: 1),
                ],
                rim: [.white.opacity(0.95), .black.opacity(0.06), .white.opacity(0.7)],
                handle: .black.opacity(0.35),
                selection: Color(white: 0.90).opacity(0.97),
                selectionRim: .black.opacity(0.06),
                iconBackground: Color(white: 0.84),
                iconForeground: Color(white: 0.30),
                iconRim: .black.opacity(0.08),
                peekDivider: .black.opacity(0.10),
                peekWell: .black.opacity(0.05),
                peekStripe: .black.opacity(0.045),
                peekShadow: .black.opacity(0.12)
            )
        default:
            SiriGlassStyle(
                tint: [
                    .init(color: .black.opacity(0.95), location: 0),
                    .init(color: .black.opacity(0.90), location: 0.55),
                    .init(color: .black.opacity(0.38), location: 0.84),
                    .init(color: .black.opacity(0.06), location: 1),
                ],
                rim: [.white.opacity(0.40), .white.opacity(0.08), .white.opacity(0.22)],
                handle: .white.opacity(0.85),
                selection: Color(white: 0.24).opacity(0.97),
                selectionRim: .white.opacity(0.10),
                iconBackground: Color(white: 0.36),
                iconForeground: Color(white: 0.97),
                iconRim: .white.opacity(0.12),
                peekDivider: .white.opacity(0.12),
                peekWell: .white.opacity(0.06),
                peekStripe: .white.opacity(0.06),
                peekShadow: .black.opacity(0.35)
            )
        }
    }
}
