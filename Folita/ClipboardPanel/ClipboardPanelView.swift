import SwiftUI

struct ClipboardPanelView: View {
    var body: some View {
        SiriGlassContainer {
            VStack(alignment: .leading, spacing: 20) {
                header
                ClipboardHistoryEmptyView()
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(
            width: ClipboardPanelMetrics.containerSize.width,
            height: ClipboardPanelMetrics.containerSize.height
        )
        .shadow(color: .black.opacity(0.28), radius: 22, y: 10)
        .padding(ClipboardPanelMetrics.shadowInset)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Clipboard")
                .font(.system(size: 26, weight: .semibold))
            Text("Recent copies")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
    }
}

/// 历史列表的占位；接入剪贴板监听后替换为真实列表。
struct ClipboardHistoryEmptyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.secondary)
            Text("No clipboard history yet")
                .font(.system(size: 20, weight: .medium))
            Text("Copied text, images and files will appear here.")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 24)
    }
}

#Preview("Dark") {
    ClipboardPanelView()
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    ClipboardPanelView()
        .preferredColorScheme(.light)
}
