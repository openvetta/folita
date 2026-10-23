import SwiftUI

/// 右上角筛选气泡：最上面一行是「收藏夹」模式开关，分隔线下面是按类型的筛选。
/// 两个维度可以叠加：在收藏夹里选「仅链接」只筛收藏里的链接（见 docs/adr/0006）。
struct ClipboardFilterMenu: View {
    @Bindable var model: ClipboardPanelModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            modeRow
            separator
            ForEach(ClipboardFilter.allCases) { filter in
                row(for: filter)
            }
        }
        .padding(6)
        .frame(width: 244)
    }

    /// 收藏夹置顶：在剪贴板按 ⌘← 打开，在收藏夹按 ⌘→ 退回剪贴列表。
    private var modeRow: some View {
        Button {
            model.perform(.toggleFavorites)
            dismiss()
        } label: {
            FilterRowLabel(
                symbolName: ClipboardPanelMode.favorites.symbolName,
                title: Text(ClipboardPanelMode.favorites.title),
                isSelected: model.mode == .favorites,
                keyCaps: model.mode == .favorites
                    ? ClipboardActionsMenuEntry.closeFavoritesKeyCaps
                    : ClipboardActionsMenuEntry.openFavoritesKeyCaps
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.mode == .favorites ? .isSelected : [])
    }

    private var separator: some View {
        Rectangle()
            .fill(.primary.opacity(0.08))
            .frame(height: 1)
            .padding(.vertical, 4)
    }

    private func row(for filter: ClipboardFilter) -> some View {
        Button {
            model.filter = filter
            dismiss()
        } label: {
            FilterRowLabel(
                symbolName: filter.symbolName,
                title: Text(filter.title),
                isSelected: filter == model.filter,
                keyCaps: []
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(filter == model.filter ? .isSelected : [])
    }
}

private struct FilterRowLabel: View {
    let symbolName: String
    let title: Text
    let isSelected: Bool
    /// 这一行对应的快捷键，没有时留空。
    var keyCaps: [String] = []

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 15, weight: .regular))
                .frame(width: 22)
            title
                .font(.system(size: 17))
            Spacer(minLength: 0)
            if !keyCaps.isEmpty {
                HStack(spacing: 4) {
                    ForEach(keyCaps, id: \.self) { key in
                        KeyCap(key)
                    }
                }
            }
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
