import SwiftUI

/// 顶栏右侧的液态玻璃搜索胶囊。
struct ClipboardSearchField: View {
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Search…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused(isFocused)
                .accessibilityLabel(Text("Search"))

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(Text("Clear Search"))
                .accessibilityLabel(Text("Clear Search"))
            }
        }
        .padding(.horizontal, 12)
        .frame(width: ClipboardPanelMetrics.searchFieldWidth, height: ClipboardPanelMetrics.controlHeight)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}
