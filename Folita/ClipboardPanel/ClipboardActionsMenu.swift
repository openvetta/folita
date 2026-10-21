import SwiftUI

/// 「更多操作」菜单里的条目。这里的快捷键与 `ClipboardPanelCommand` 的按键映射一一对应：
/// 菜单只是引导，这些键在面板里不打开菜单也能直接按。
enum ClipboardActionsMenuEntry: CaseIterable {
    /// 粘贴到呼出面板时所在的应用（↩），执行后面板收起。
    case pasteToTarget
    /// 粘贴但保持面板打开（⌥↩），用于连续粘贴多条。
    case pasteKeepingPanelOpen
    case pasteAsPlainText
    case deleteEntry
    case deleteAll

    /// 拆分后的按键，每个键一个键帽：修饰键不与字母挤在同一格里。
    var keyCaps: [String] {
        switch self {
        case .pasteToTarget: ["↩"]
        case .pasteKeepingPanelOpen: ["⌥", "↩"]
        case .pasteAsPlainText: ["⇧", "↩"]
        case .deleteEntry: ["⌃", "X"]
        case .deleteAll: ["⌃", "⇧", "X"]
        }
    }

    /// 连写形式，用于设置页里成段的按键说明。
    var shortcut: String { keyCaps.joined() }

    var command: ClipboardPanelCommand {
        switch self {
        case .pasteToTarget: .paste(.original)
        case .pasteKeepingPanelOpen: .pasteKeepingPanelOpen
        case .pasteAsPlainText: .paste(.plainText)
        case .deleteEntry: .deleteSelected
        case .deleteAll: .deleteAll
        }
    }

    /// 删除动作单独成组，卡片里在它之前画一道分割线。
    var startsNewGroup: Bool { self == .deleteEntry }

    var isDestructive: Bool { self == .deleteEntry || self == .deleteAll }

    func title(targetAppName: String?) -> LocalizedStringResource {
        switch self {
        case .pasteToTarget:
            if let targetAppName {
                "Paste to \(targetAppName)"
            } else {
                "Paste"
            }
        case .pasteKeepingPanelOpen: "Paste and Keep Window Open"
        case .pasteAsPlainText: "Paste as Plain Text"
        case .deleteEntry: "Delete Entry"
        case .deleteAll: "Delete All Entries"
        }
    }

    /// 列表行右侧常驻的「打开菜单」提示：⌘ 与 K 分成两个键帽，连写用于设置页。
    static let menuHintKeyCaps = ["⌘", "K"]

    /// 取第 index 项；越界返回 nil（↑↓ 已在外面夹住范围，这里只做兜底）。
    static func entry(at index: Int) -> ClipboardActionsMenuEntry? {
        allCases.indices.contains(index) ? allCases[index] : nil
    }
}

/// 选中条目右侧的「更多操作」卡片：右键条目或按 ⌘K 打开，每行右侧标出可直接按的键。
/// 卡片尺寸与位置由 `ClipboardPanelMetrics.actionsMenuFrame(anchoredTo:entryCount:in:)` 给出，
/// 与这里固定的行高、内边距和分割线高度保持一致。
struct ClipboardActionsMenuView: View {
    var targetAppName: String?
    /// 当前高亮项，↑↓ 或鼠标悬停都会改它，↩ 执行的就是这一项。
    var highlighted: ClipboardActionsMenuEntry?
    var perform: (ClipboardPanelCommand) -> Void
    var highlight: (ClipboardActionsMenuEntry) -> Void = { _ in }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let style = SiriGlassStyle.resolve(for: colorScheme)
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        VStack(spacing: 0) {
            ForEach(Array(ClipboardActionsMenuEntry.allCases.enumerated()), id: \.element) { index, entry in
                if entry.startsNewGroup, index > 0 {
                    separator(style)
                }
                ClipboardActionsMenuRow(
                    entry: entry,
                    title: Text(entry.title(targetAppName: targetAppName)),
                    isHighlighted: entry == highlighted,
                    style: style,
                    action: { perform(entry.command) },
                    highlight: { highlight(entry) }
                )
            }
        }
        .padding(ClipboardPanelMetrics.actionsMenuPadding)
        // 原生液态玻璃：卡片浮在面板内容之上，背后的列表会被折射，而不是盖一层不透明底色。
        .glassEffect(.regular, in: shape)
        .overlay { shape.strokeBorder(style.menuRim, lineWidth: 1) }
        .shadow(color: style.shadow, radius: 10, y: 3)
        .accessibilityElement(children: .contain)
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

/// 菜单中的一行：左侧动作名称，右侧拆开的键帽。高亮只换底色，选中项与 ↑↓ 同步。
private struct ClipboardActionsMenuRow: View {
    let entry: ClipboardActionsMenuEntry
    let title: Text
    let isHighlighted: Bool
    let style: SiriGlassStyle
    let action: () -> Void
    let highlight: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                title
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    ForEach(entry.keyCaps, id: \.self) { key in
                        KeyCap(key)
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
        .foregroundStyle(entry.isDestructive ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
        .onHover { isHovering in
            if isHovering { highlight() }
        }
    }
}

#Preview("Dark") {
    ClipboardActionsMenuView(targetAppName: "Safari", highlighted: .pasteKeepingPanelOpen, perform: { _ in })
        .padding(24)
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    ClipboardActionsMenuView(targetAppName: "Xcode", highlighted: .pasteToTarget, perform: { _ in })
        .padding(24)
        .preferredColorScheme(.light)
}
