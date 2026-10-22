import AppKit
import SwiftUI

/// 主窗口的收藏夹分区：左侧条目列表（顶部一排分组胶囊），右侧详情。
///
/// 与面板里的收藏夹共用同一套数据（`ClipboardHistoryStore`）和同一个分组胶囊组件，
/// 只是宿主更宽、能看到完整详情，所以这里不做粘贴与快捷键，
/// 提供「浏览 + 手动新建/编辑文本 + 取消收藏 + 管理分组」。
///
/// 新建与编辑都在右侧详情栏就地完成，不弹窗：点「添加」在列表里落一条 New Snippet 并
/// 让右侧变成可编辑的编辑器，用户直接输入即可；「编辑」则把当前条目切换成同样的编辑器。
/// 输入内容实时写回存储，离开编辑器或切换条目时收尾（草稿为空则丢弃）。
struct FavoritesView: View {
    @Environment(ClipboardHistoryStore.self) private var store

    @State private var selectedID: UUID?
    @State private var selectedTabID: UUID?
    @State private var renamingTabID: UUID?
    @State private var renameDraft = ""

    /// 详情栏是否处于编辑器状态。
    @State private var isEditing = false
    /// 正在编辑的条目；与 `selectedID` 同步。
    @State private var draftID: UUID?
    /// 编辑器里的当前文本。
    @State private var draftText = ""
    /// 进入编辑器时的文本，用来判断是否需要写回。
    @State private var draftSnapshot = ""
    /// 这条草稿是否是「添加」新建的空条目：为空离开时要删掉它。
    @State private var draftCreatedNew = false

    private static let listColumnWidth: CGFloat = 280

    var body: some View {
        HStack(spacing: 0) {
            listColumn
                .frame(width: Self.listColumnWidth)
            Divider()
            detail
                .frame(maxWidth: .infinity)
        }
        // 离开分区时把还没收尾的草稿落盘（空的新草稿丢弃）。
        .onDisappear { if isEditing { finalizeDraft(); isEditing = false } }
    }

    // MARK: 选中与数据

    /// 可新建片段的目标分组：优先当前选中的分组，否则第一个。
    private var newSnippetTab: FavoriteTab? {
        selectedTab ?? store.tabs.first
    }

    private var selectedTab: FavoriteTab? {
        guard let selectedTabID else { return nil }
        return store.tabs.first { $0.id == selectedTabID }
    }

    private var tabItems: [HistoryItem] {
        guard let selectedTab else { return store.favorites }
        return store.favorites.filter { $0.favoriteTab?.id == selectedTab.id }
    }

    private var selectedItem: HistoryItem? {
        tabItems.first { $0.id == selectedID } ?? tabItems.first
    }

    // MARK: 列表栏

    private var listColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            FavoriteTabBar(
                tabs: store.tabs,
                selectedTabID: selectedTabID,
                renamingTabID: $renamingTabID,
                renameDraft: $renameDraft,
                // 换分组后选中项可能已不在列表里，交回给 selectedItem 兜底。
                select: selectTab,
                create: { store.createTab(named: String(localized: "New Group")) },
                rename: store.renameTab,
                delete: { tab in
                    if selectedTabID == tab.id { selectedTabID = nil }
                    store.deleteTab(tab)
                }
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            actionBar

            Divider()

            if tabItems.isEmpty {
                emptyListState
            } else {
                List {
                    ForEach(tabItems) { item in
                        row(for: item)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                            .contentShape(.rect)
                            .onTapGesture { select(item) }
                            .contextMenu {
                                if item.category.isTextual {
                                    Button("Edit") {
                                        select(item)
                                        if !isEditing { toggleEditing() }
                                    }
                                }
                                Button("Remove from Favorites") { removeFromFavorites(item) }
                            }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
    }

    /// 列表栏工具的顶部一栏：左侧「添加」，右侧「编辑 / 完成」。都用无边框按钮，轻量贴合 macOS 侧栏。
    private var actionBar: some View {
        HStack(spacing: 8) {
            Button {
                startNewSnippet()
            } label: {
                Label("Add Snippet", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .disabled(store.tabs.isEmpty)
            .help(Text("Add Snippet"))

            Spacer(minLength: 0)

            Button {
                toggleEditing()
            } label: {
                Label(editToggleTitle, systemImage: editToggleSymbol)
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .disabled(store.tabs.isEmpty || (!isEditing && !canEditSelection))
            .help(Text(editToggleTitle))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    /// 「编辑 / 完成」的文案与图标随编辑状态切换；用 `LocalizedStringResource` 保证两种语言都本地化。
    private var editToggleTitle: LocalizedStringResource {
        isEditing ? "Done" : "Edit"
    }

    private var editToggleSymbol: String {
        isEditing ? "checkmark" : "square.and.pencil"
    }

    @ViewBuilder
    private func row(for item: HistoryItem) -> some View {
        let isSelected = item.id == (isEditing ? draftID : selectedItem?.id)
        if isEditing, item.id == draftID {
            FavoriteSnippetDraftRow(text: draftText, isSelected: isSelected)
        } else {
            FavoriteItemRow(item: item, isSelected: isSelected)
        }
    }

    private var emptyListState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "note.text")
                .font(.system(size: 26, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            // 用局部资源而非三元字符串：三元会被推断成 String，走 verbatim 而绕过本地化。
            if store.tabs.isEmpty {
                emptyTitle("Create a group first")
                emptyMessage("Make a group with the + button, then add snippets here.")
            } else {
                emptyTitle("No snippets yet")
                emptyMessage("Add a snippet to save text you want to keep close.")
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func emptyTitle(_ title: LocalizedStringResource) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
    }

    private func emptyMessage(_ message: LocalizedStringResource) -> some View {
        Text(message)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: 详情

    @ViewBuilder
    private var detail: some View {
        if isEditing, draftID != nil {
            SnippetEditor(
                text: $draftText,
                characterCount: draftText.count,
                done: stopEditing
            )
        } else if let item = selectedItem {
            itemDetail(item)
        } else {
            ContentUnavailableView {
                Label("Nothing to preview", systemImage: "rectangle.dashed")
            } description: {
                Text("Select a snippet, or add a new one.")
            }
        }
    }

    private func itemDetail(_ item: HistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(verbatim: ClipboardHistoryRow.title(of: item))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button("Remove from Favorites", systemImage: "star.slash") {
                    removeFromFavorites(item)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help(Text("Remove from Favorites"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                ClipPeekCard(
                    item: item,
                    onOpenInFinder: { openInFinder(item) },
                    onOpenInBrowser: { openInBrowser(item) },
                    onComposeEmail: { address in
                        if let url = EmailAddresses.mailtoURL(to: address) { NSWorkspace.shared.open(url) }
                    },
                    // 主窗口不粘贴，颜色转换在这里没有落点。
                    onConvertColor: { _ in }
                )
                .padding(16)
            }
        }
    }

    // MARK: 编辑状态机

    /// 当前选中项能否编辑：只有文本类条目有可编辑的正文。
    private var canEditSelection: Bool {
        selectedItem?.category.isTextual == true
    }

    private func select(_ item: HistoryItem) {
        if isEditing {
            guard item.id != draftID else { return }
            finalizeDraft()
            if item.category.isTextual {
                beginEditing(item)
                selectedID = item.id
            } else {
                isEditing = false
                selectedID = item.id
            }
            return
        }
        selectedID = item.id
    }

    private func selectTab(_ id: UUID?) {
        if isEditing { finishEditing() }
        selectedTabID = id
        selectedID = nil
    }

    private func startNewSnippet() {
        guard let tab = newSnippetTab else { return }
        finishEditing()
        let item = store.insertEmptySnippet(in: tab)
        selectedTabID = tab.id
        selectedID = item.id
        draftText = ""
        draftSnapshot = ""
        draftCreatedNew = true
        draftID = item.id
        isEditing = true
    }

    private func toggleEditing() {
        if isEditing {
            stopEditing()
        } else if let item = selectedItem, item.category.isTextual {
            beginEditing(item)
            isEditing = true
        }
    }

    private func beginEditing(_ item: HistoryItem) {
        let text = ClipClassification.plainText(in: item.clipContents) ?? ""
        draftText = text
        draftSnapshot = text
        draftCreatedNew = false
        draftID = item.id
    }

    /// 退出编辑器：先收尾，再切回只读详情。
    private func stopEditing() {
        finishEditing()
        isEditing = false
    }

    /// 收尾并退出编辑器（用于切换分组等场景）。
    private func finishEditing() {
        finalizeDraft()
        isEditing = false
    }

    /// 把草稿写回存储：新建但为空的丢弃，其余有变化才更新。
    private func finalizeDraft() {
        guard let id = draftID else { return }
        guard let item = store.items.first(where: { $0.id == id }) else {
            draftID = nil
            draftCreatedNew = false
            return
        }
        let isBlank = draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if draftCreatedNew, isBlank {
            if selectedID == item.id { selectedID = nil }
            store.delete(item)
        } else if draftText != draftSnapshot {
            store.updateText(item, to: draftText)
        }
        draftID = nil
        draftCreatedNew = false
        draftSnapshot = draftText
    }

    private func removeFromFavorites(_ item: HistoryItem) {
        // 正编辑着这条：新建且还没实质内容就直接删掉；否则有内容就保留，仅退出编辑。
        if draftID == item.id {
            let isBlank = draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if draftCreatedNew, isBlank {
                draftID = nil
                draftCreatedNew = false
                isEditing = false
                if selectedID == item.id { selectedID = nil }
                store.delete(item)
                return
            }
            if draftText != draftSnapshot { store.updateText(item, to: draftText) }
            draftID = nil
            draftCreatedNew = false
            isEditing = false
        }
        if selectedID == item.id { selectedID = nil }
        store.unfavorite(item)
    }

    private func openInFinder(_ item: HistoryItem) {
        guard let urls = ClipClassification.fileURLs(in: item.clipContents) else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    private func openInBrowser(_ item: HistoryItem) {
        guard let url = ClipDetails(contents: item.clipContents, category: item.category).link else { return }
        NSWorkspace.shared.open(url)
    }
}

/// 主窗口列表里的一行：比面板的行更宽，标题能占满整行。
private struct FavoriteItemRow: View {
    let item: HistoryItem
    var isSelected = false

    @Environment(\.colorScheme) private var colorScheme

    private var title: String {
        let title = ClipboardHistoryRow.title(of: item)
        return title.isEmpty ? String(localized: "New Snippet") : title
    }

    var body: some View {
        let style = SiriGlassStyle.resolve(for: colorScheme)
        HStack(spacing: 10) {
            Image(systemName: item.category.symbolName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 22)
                .foregroundStyle(isSelected ? AnyShapeStyle(style.iconForeground) : AnyShapeStyle(.secondary))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(item.lastCopiedAt, format: .relative(presentation: .named))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(style.selection)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 「添加」新建但尚未输入时的占位行：与普通行同高，提示用户正在新建。
private struct FavoriteSnippetDraftRow: View {
    let text: String
    var isSelected = true

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let style = SiriGlassStyle.resolve(for: colorScheme)
        HStack(spacing: 10) {
            Image(systemName: ClipCategory.text.symbolName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 22)
                .foregroundStyle(style.iconForeground)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: text.isEmpty ? String(localized: "New Snippet") : text)
                    .font(.system(size: 13, weight: .medium))
                    .italic(text.isEmpty)
                    .foregroundStyle(text.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .lineLimit(1)
                Text("Editing")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(style.selection)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// 详情栏里的片段编辑器：一条与详情预览同质地的「文本框」，顶部一行提示与「完成」。
/// 只负责展示与输入，内容通过绑定回传给 `FavoritesView`，由它统一落库。
struct SnippetEditor: View {
    @Binding var text: String
    let characterCount: Int
    var done: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    var body: some View {
        let style = SiriGlassStyle.resolve(for: colorScheme)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Label("Snippet", systemImage: ClipCategory.text.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                Spacer(minLength: 8)
                Button("Done", action: done)
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.borderless)
                    // 不给默认回车动作：多行编辑器里回车应换行，否则没法输入多行内容。
                    .help(Text("Done"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            editorWell(style: style)
                .padding(16)

            Text("\(characterCount) characters")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
        }
        .accessibilityLabel(Text("Snippet"))
        // 编辑器一出现就把第一响应者交给输入框，用户可以直接打字。
        .onAppear { isFocused = true }
    }

    private func editorWell(style: SiriGlassStyle) -> some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Type or paste text here…")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(.system(size: 13, design: .monospaced))
                .lineSpacing(3)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .focused($isFocused)
                .accessibilityLabel(Text("Snippet"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(style.peekWell, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style.iconRim, lineWidth: 1)
        }
    }
}
