import SwiftUI

/// Siri 新 UI 质地的取色：上部高不透明度着色承载文字，下部渐隐露出底层玻璃，
/// 再以一圈高光描边勾出容器边缘。深浅色外观各自一套，禁止在视图中硬编码颜色。
struct SiriGlassStyle: Equatable {
    var tint: [Gradient.Stop]
    var rim: [Color]
    var handle: Color

    /// 内容在容器底部渐隐的蒙版，与着色渐隐的节奏保持一致。
    static let contentFade: [Gradient.Stop] = [
        .init(color: .black, location: 0),
        .init(color: .black, location: 0.70),
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
                handle: .black.opacity(0.35)
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
                handle: .white.opacity(0.85)
            )
        }
    }
}
