import SwiftUI

/// 复制到剪贴板后在面板底部短暂出现的提示，带上复制的内容，让用户确认拿到的是哪个色值。
struct CopyFeedbackToast: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text("Copied to Clipboard")
                .font(.system(size: 13, weight: .medium))
            Text(verbatim: text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
    }
}
