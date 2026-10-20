import SwiftUI

/// 面板标题下方的权限提示，点击前往系统设置修复。
struct PanelNoticeBanner: View {
    let notice: PanelNotice
    let action: () -> Void

    var body: some View {
        if let content {
            Button(action: action) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: content.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(content.title)
                            .font(.system(size: 13, weight: .semibold))
                        Text(content.message)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(12)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            .accessibilityElement(children: .combine)
        }
    }

    private var content: (symbol: String, title: LocalizedStringResource, message: LocalizedStringResource)? {
        switch notice {
        case .none:
            nil
        case .accessibilityNeeded:
            (
                "hand.raised",
                "Auto-paste needs permission",
                "Selected items are copied — press ⌘V to paste. Click to grant permission in System Settings."
            )
        case .pasteboardDenied:
            (
                "exclamationmark.triangle",
                "Clipboard access is denied",
                "Folita can't record new copies. Click to allow clipboard access in System Settings."
            )
        }
    }
}
