import SwiftUI

/// 菜单标题：固定文案走本地化，邮箱地址、格式名这类内容原样显示。
enum ClipboardMenuTitle: Equatable {
    case localized(LocalizedStringResource)
    case verbatim(String)

    var text: Text {
        switch self {
        case .localized(let resource): Text(resource)
        case .verbatim(let string): Text(verbatim: string)
        }
    }
}

/// 「更多操作」菜单里的条目。粘贴与删除固定存在，其余由选中条目的内容决定；
/// 带二级菜单的条目（多个邮箱、颜色转换）在菜单里就地展开。
/// 固定条目的快捷键与 `ClipboardPanelCommand` 的按键映射一一对应：菜单只是引导，这些键不打开菜单也能直接按。
enum ClipboardActionsMenuEntry: Hashable {
    /// 粘贴到呼出面板时所在的应用（↩），执行后面板收起。
    case pasteToTarget
    /// 粘贴但保持面板打开（⌥↩），用于连续粘贴多条。
    case pasteKeepingPanelOpen
    case pasteAsPlainText
    case openInBrowser
    /// 内容里的邮件地址；多于一个时展开为逐个地址的二级菜单。
    case sendEmail(addresses: [String])
    case sendEmailTo(String)
    /// `excluding` 是文本当前已用的格式，不再作为转换目标。
    case convertColor(RGBAColor, excluding: ColorFormat?)
    /// `text` 是转换后的色值，直接写在菜单项上。
    case convertTo(ColorFormat, text: String)
    /// 收藏到某个分组，或改到另一个分组（⌘F）。
    case favorite
    case deleteEntry
    case deleteAll

    /// 选中条目的内容决定出现哪些条目，顺序即菜单顺序。
    static func entries(for details: ClipDetails) -> [ClipboardActionsMenuEntry] {
        var entries: [ClipboardActionsMenuEntry] = [.pasteToTarget, .pasteKeepingPanelOpen, .pasteAsPlainText]
        if details.link != nil { entries.append(.openInBrowser) }
        if !details.emails.isEmpty { entries.append(.sendEmail(addresses: details.emails)) }
        if let color = details.color { entries.append(.convertColor(color, excluding: details.colorFormat)) }
        entries += [.favorite, .deleteEntry, .deleteAll]
        return entries
    }

    /// 拆分后的按键，每个键一个键帽：修饰键不与字母挤在同一格里。只有固定条目有快捷键。
    var keyCaps: [String] {
        switch self {
        case .pasteToTarget: ["↩"]
        case .pasteKeepingPanelOpen: ["⌥", "↩"]
        case .pasteAsPlainText: ["⇧", "↩"]
        case .deleteEntry: ["⌃", "X"]
        case .favorite: ClipboardActionsMenuEntry.favoriteKeyCaps
        case .deleteAll: ["⌃", "⇧", "X"]
        default: []
        }
    }

    /// 连写形式，用于设置页里成段的按键说明。
    var shortcut: String { keyCaps.joined() }

    /// 二级菜单；空表示直接执行。
    var children: [ClipboardActionsMenuEntry] {
        switch self {
        case .sendEmail(let addresses) where addresses.count > 1:
            addresses.map { .sendEmailTo($0) }
        case .convertColor(let color, let excluding):
            ColorFormat.allCases.filter { $0 != excluding }.map { .convertTo($0, text: $0.string(for: color)) }
        default:
            []
        }
    }

    /// 带二级菜单的条目没有自己的命令。
    var command: ClipboardPanelCommand? {
        switch self {
        case .pasteToTarget: .paste(.original)
        case .pasteKeepingPanelOpen: .pasteKeepingPanelOpen
        case .pasteAsPlainText: .paste(.plainText)
        case .openInBrowser: .openInBrowser
        case .sendEmail(let addresses): addresses.count == 1 ? .composeEmail(addresses[0]) : nil
        case .sendEmailTo(let address): .composeEmail(address)
        case .convertColor: nil
        case .convertTo(let format, _): .convertColor(format)
        case .favorite: .toggleFavoritePicker
        case .deleteEntry: .deleteSelected
        case .deleteAll: .deleteAll
        }
    }

    /// 分组：粘贴 / 针对内容的操作 / 删除，组与组之间画分割线。二级条目随父条目。
    var group: Int {
        switch self {
        case .pasteToTarget, .pasteKeepingPanelOpen, .pasteAsPlainText: 0
        case .openInBrowser, .sendEmail, .sendEmailTo, .convertColor, .convertTo: 1
        case .favorite: 2
        case .deleteEntry, .deleteAll: 3
        }
    }

    var isDestructive: Bool { self == .deleteEntry || self == .deleteAll }

    func title(targetAppName: String?) -> ClipboardMenuTitle {
        switch self {
        case .pasteToTarget:
            if let targetAppName {
                .localized("Paste to \(targetAppName)")
            } else {
                .localized("Paste")
            }
        case .pasteKeepingPanelOpen: .localized("Paste and Keep Window Open")
        case .pasteAsPlainText: .localized("Paste as Plain Text")
        case .openInBrowser: .localized("Open in Browser")
        case .sendEmail: .localized("Send Email")
        case .sendEmailTo(let address): .verbatim(address)
        case .convertColor: .localized("Convert Color")
        case .convertTo(_, let text): .verbatim(text)
        case .deleteEntry: .localized("Delete Entry")
        case .favorite: .localized("Favorite")
        case .deleteAll: .localized("Delete All Entries")
        }
    }

    /// 列表行右侧常驻的「打开菜单」提示：⌘ 与 K 分成两个键帽，连写用于设置页。
    static let menuHintKeyCaps = ["⌘", "K"]

    /// 收藏动作的快捷键：⌘F 与 ⌘K 同构，不打开菜单也能直接按。
    static let favoriteKeyCaps = ["⌘", "F"]

    /// 在剪贴列表与收藏夹之间切换的快捷键（⌘←）。
    static let favoritesKeyCaps = ["⌘", "←"]
}

/// 菜单里的一行：一级条目，或展开条目的二级条目（二级条目画在一级卡片旁边的另一张卡片里）。
struct ClipboardActionsMenuRow: Identifiable, Equatable {
    let entry: ClipboardActionsMenuEntry
    let depth: Int

    var id: ClipboardActionsMenuEntry { entry }

    /// 把条目铺平成行：展开的条目其二级条目紧跟在后面，键盘 ↑↓ 按这个顺序移动。
    static func rows(of entries: [ClipboardActionsMenuEntry], expanded: ClipboardActionsMenuEntry?) -> [ClipboardActionsMenuRow] {
        entries.flatMap { entry -> [ClipboardActionsMenuRow] in
            let row = ClipboardActionsMenuRow(entry: entry, depth: 0)
            guard entry == expanded else { return [row] }
            return [row] + entry.children.map { ClipboardActionsMenuRow(entry: $0, depth: 1) }
        }
    }

    /// 相邻两行分属不同组的次数，即分割线条数。
    static func separatorCount(in rows: [ClipboardActionsMenuRow]) -> Int {
        zip(rows, rows.dropFirst()).filter { $0.entry.group != $1.entry.group }.count
    }
}

/// 选中条目右侧的「更多操作」卡片：右键条目或按 ⌘K 打开，每行右侧标出可直接按的键。
/// 只画一级行；展开的二级条目由 `ClipboardActionsSubmenuView` 画在它旁边。
/// 卡片尺寸与位置由 `ClipboardPanelMetrics.actionsMenuSize(rowCount:separatorCount:)` 给出，
/// 与这里固定的行高、内边距和分割线高度保持一致。
struct ClipboardActionsMenuView: View {
    /// 一级行。
    var rows: [ClipboardActionsMenuRow]
    var targetAppName: String?
    /// 当前高亮项，↑↓ 或鼠标悬停都会改它，↩ 执行的就是这一项。
    var highlighted: ClipboardActionsMenuEntry?
    /// 已展开二级菜单的条目。
    var expanded: ClipboardActionsMenuEntry?
    /// 点击一行：执行它的命令，或展开它的二级菜单。
    var activate: (ClipboardActionsMenuEntry) -> Void
    var highlight: (ClipboardActionsMenuEntry) -> Void = { _ in }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let style = SiriGlassStyle.resolve(for: colorScheme)

        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0, rows[index - 1].entry.group != row.entry.group {
                    separator(style)
                }
                ClipboardActionsMenuRowView(
                    row: row,
                    title: row.entry.title(targetAppName: targetAppName).text,
                    isHighlighted: row.entry == highlighted,
                    isExpanded: row.entry == expanded,
                    style: style,
                    action: { activate(row.entry) },
                    highlight: { highlight(row.entry) }
                )
            }
        }
        .actionsMenuCard(style)
        .accessibilityLabel(Text("More Actions"))
    }

    private func separator(_ style: SiriGlassStyle) -> some View {
        Rectangle()
            .fill(style.menuDivider)
            .frame(height: 1)
            .padding(.vertical, 4)
            .frame(height: ClipboardPanelMetrics.actionsMenuSeparatorHeight)
    }
}

/// 二级菜单卡片：画在一级卡片旁边，行与一级菜单同高；没有分组，也没有键帽。
struct ClipboardActionsSubmenuView: View {
    var rows: [ClipboardActionsMenuRow]
    var highlighted: ClipboardActionsMenuEntry?
    var activate: (ClipboardActionsMenuEntry) -> Void
    var highlight: (ClipboardActionsMenuEntry) -> Void = { _ in }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let style = SiriGlassStyle.resolve(for: colorScheme)

        VStack(spacing: 0) {
            ForEach(rows) { row in
                ClipboardActionsMenuRowView(
                    row: row,
                    title: row.entry.title(targetAppName: nil).text,
                    isHighlighted: row.entry == highlighted,
                    isExpanded: false,
                    style: style,
                    action: { activate(row.entry) },
                    highlight: { highlight(row.entry) }
                )
            }
        }
        .actionsMenuCard(style)
    }
}

private extension View {
    /// 一级与二级卡片共用的玻璃外观。
    func actionsMenuCard(_ style: SiriGlassStyle) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return padding(ClipboardPanelMetrics.actionsMenuPadding)
            // 原生液态玻璃：卡片浮在面板内容之上，背后的列表会被折射，而不是盖一层不透明底色。
            .glassEffect(.regular, in: shape)
            .overlay { shape.strokeBorder(style.menuRim, lineWidth: 1) }
            .shadow(color: style.shadow, radius: 10, y: 3)
            .accessibilityElement(children: .contain)
    }
}

/// 菜单中的一行：左侧动作名称，右侧拆开的键帽或展开箭头。高亮只换底色，选中项与 ↑↓ 同步。
private struct ClipboardActionsMenuRowView: View {
    let row: ClipboardActionsMenuRow
    let title: Text
    let isHighlighted: Bool
    let isExpanded: Bool
    let style: SiriGlassStyle
    let action: () -> Void
    let highlight: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                title
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                if !row.entry.children.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                } else {
                    HStack(spacing: 4) {
                        ForEach(row.entry.keyCaps, id: \.self) { key in
                            KeyCap(key)
                        }
                    }
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
        .foregroundStyle(row.entry.isDestructive ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
        .accessibilityAddTraits(isExpanded ? .isSelected : [])
        .onHover { isHovering in
            if isHovering { highlight() }
        }
    }
}

private let previewDetails = ClipDetails(
    contents: [ClipContent(type: .string, data: Data("https://folita.app".utf8))],
    category: .link
)

#Preview("Dark") {
    let rows = ClipboardActionsMenuRow.rows(of: ClipboardActionsMenuEntry.entries(for: previewDetails), expanded: nil)
    ClipboardActionsMenuView(rows: rows, targetAppName: "Safari", highlighted: .openInBrowser, expanded: nil, activate: { _ in })
        .padding(24)
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    let rows = ClipboardActionsMenuRow.rows(of: ClipboardActionsMenuEntry.entries(for: previewDetails), expanded: nil)
    ClipboardActionsMenuView(rows: rows, targetAppName: "Xcode", highlighted: .pasteToTarget, expanded: nil, activate: { _ in })
        .padding(24)
        .preferredColorScheme(.light)
}
