import SwiftUI

/// 顶栏中间的全宽搜索输入：无胶囊、无背景，只有大号文字与占位符。
struct ClipboardSearchField: View {
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            TextField("Search…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 22))
                .focused(isFocused)
                .accessibilityLabel(Text("Search"))

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(Text("Clear Search"))
                .accessibilityLabel(Text("Clear Search"))
            }
        }
        .frame(maxWidth: .infinity, minHeight: ClipboardPanelMetrics.controlHeight, alignment: .leading)
    }
}
