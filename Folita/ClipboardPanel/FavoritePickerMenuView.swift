import SwiftUI

/// 「收藏到分组」选择器（⌘F）：与「更多操作」菜单同构的玻璃卡片，
/// 锚在当前选中条目下方，↑↓ 选择、↩ 确认、Esc / ⌘F 收起。
struct FavoritePickerMenuView: View {
    let rows: [FavoritePickerRow]
    let tabs: [FavoriteTab]
    /// 条目当前所属的分组，用来给那一行打勾。
    let currentTabID: UUID?
    let highlighted: FavoritePickerRow?
    let activate: (FavoritePickerRow) -> Void
    let highlight: (FavoritePickerRow) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let style = SiriGlassStyle.resolve(for: colorScheme)

        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element) { index, row in
                if index > 0, needsSeparator(before: row) {
                    separator(style)
                }
                rowView(row, style: style)
            }
        }
        .padding(ClipboardPanelMetrics.actionsMenuPadding)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style.menuRim, lineWidth: 1)
        }
        .shadow(color: style.shadow, radius: 10, y: 3)
        .accessibilityLabel(Text("Favorite"))
        .accessibilityElement(children: .contain)
    }

    /// 「取消收藏」与分组之间画一道分割线，避免误按。
    private func needsSeparator(before row: FavoritePickerRow) -> Bool {
        row == .unfavorite
    }

    private func rowView(_ row: FavoritePickerRow, style: SiriGlassStyle) -> some View {
        let isHighlighted = row == highlighted

        return Button {
            activate(row)
        } label: {
            HStack(spacing: 10) {
                title(of: row)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                if row == .unfavorite {
                    KeyCap(ClipboardActionsMenuEntry.favoriteKeyCaps[0])
                    KeyCap(ClipboardActionsMenuEntry.favoriteKeyCaps[1])
                } else if isCurrentTab(row) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: ClipboardPanelMetrics.actionsMenuEntryHeight)
            .contentShape(.rect)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHighlighted ? style.menuHighlight : .clear)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(row == .unfavorite ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
        .onHover { isHovering in
            if isHovering { highlight(row) }
        }
    }

    private func isCurrentTab(_ row: FavoritePickerRow) -> Bool {
        guard case .tab(let id) = row else { return false }
        return id == currentTabID
    }

    private func title(of row: FavoritePickerRow) -> Text {
        switch row {
        case .tab(let id):
            if let tab = tabs.first(where: { $0.id == id }) { Text(verbatim: tab.name) } else { Text("Group") }
        case .unfavorite:
            Text("Remove from Favorites")
        case .createTab:
            Text("New Group…")
        }
    }

    private func separator(_ style: SiriGlassStyle) -> some View {
        Rectangle()
            .fill(style.menuDivider)
            .frame(height: 1)
            .padding(.vertical, 4)
            .frame(height: ClipboardPanelMetrics.actionsMenuSeparatorHeight)
    }
}
