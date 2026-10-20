import SwiftUI

/// 筛选类型气泡菜单，与 iOS 27 Siri 风格一致地只用图标与文字。
struct ClipboardFilterMenu: View {
    @Binding var selection: ClipboardFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(ClipboardFilter.allCases) { filter in
                row(for: filter)
            }
        }
        .padding(6)
        .frame(width: 244)
    }

    private func row(for filter: ClipboardFilter) -> some View {
        Button {
            selection = filter
            dismiss()
        } label: {
            FilterRowLabel(filter: filter, isSelected: filter == selection)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(filter == selection ? .isSelected : [])
    }
}

private struct FilterRowLabel: View {
    let filter: ClipboardFilter
    let isSelected: Bool

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: filter.symbolName)
                .font(.system(size: 15, weight: .regular))
                .frame(width: 22)
            Text(filter.title)
                .font(.system(size: 17))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            if isSelected || isHovering {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.primary.opacity(isSelected ? 0.14 : 0.07))
            }
        }
        .contentShape(.rect)
        .onHover { isHovering = $0 }
    }
}
