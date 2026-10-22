import AppKit
import SwiftUI

/// 主窗口收藏夹分区：极致去线留白、现代 macOS 文档风格的双栏设计。
///
/// 左侧为分组与片段卡片流，右侧为全幅沉浸式正文画布（直接可读可写，连续自动保存）。
/// 摒弃旧式的分割线叠框与老土的「编辑/完成」模式切换，像 Apple Notes 与 Bear 一样直接、轻盈、呼吸感十足。
struct FavoritesView: View {
    @Environment(ClipboardHistoryStore.self) private var store

    @State private var selectedID: UUID?
    @State private var selectedTabID: UUID?
    @State private var renamingTabID: UUID?
    @State private var renameDraft = ""

    /// 正在起草的新片段 ID（离开时若未输入任何内容则自动丢弃）。
    @State private var draftID: UUID?
    /// 详情画布的当前文本缓存，与存储层保持去抖实时同步。
    @State private var editorText = ""
    /// 当前载入编辑器的条目 ID 与原文快照，防止切换与首次加载时误触发空覆盖。
    @State private var editingItemID: UUID?
    @State private var lastLoadedText = ""

    @FocusState private var isEditorFocused: Bool

    private static let listColumnWidth: CGFloat = 290

    var body: some View {
        HStack(spacing: 0) {
            listColumn
                .frame(width: Self.listColumnWidth)

            // 去线设计：放弃生硬的 1px 黑色 Divider，使用极轻柔的透明度边界线与底色反差界定双栏。
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(width: 1)
                .accessibilityHidden(true)

            detailCanvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // 键盘全局快捷键：⌘N 直接新建片段。
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    startNewSnippet()
                } label: {
                    Label("New Snippet", systemImage: "square.and.pencil")
                }
                .disabled(store.tabs.isEmpty)
                .help(Text("New Snippet"))
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        // 视图初次展示时同步选中项与正文。
        .onAppear {
            if selectedID == nil, let first = tabItems.first {
                selectedID = first.id
                let text = first.plainText ?? ""
                editingItemID = first.id
                lastLoadedText = text
                editorText = text
            }
        }
        // 输入内容去抖自动落盘：300ms 停顿或离开时自动保存。
        .task(id: editorText) {
            guard let item = selectedItem, item.category.isTextual else { return }
            guard item.id == editingItemID else { return }
            guard editorText != lastLoadedText else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            store.updateText(item, to: editorText)
            lastLoadedText = editorText
        }
        .onDisappear {
            flushCurrentEdit()
            cleanupEmptyDraft(exempting: nil)
        }
    }

    // MARK: - 数据检索

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

    // MARK: - 左侧列表栏（去线留白）

    private var listColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar

            if tabItems.isEmpty && draftID == nil {
                emptyListState
            } else {
                snippetList
            }
        }
        .background(Color.primary.opacity(0.02))
    }

    /// 列表顶部栏：左侧为无缝滚动的分组胶囊，右侧为极简的新建片段图标按钮。去线处理，留出呼吸边距。
    private var headerBar: some View {
        HStack(spacing: 8) {
            FavoriteTabBar(
                tabs: store.tabs,
                selectedTabID: selectedTabID,
                renamingTabID: $renamingTabID,
                renameDraft: $renameDraft,
                select: selectTab,
                create: { store.createTab(named: String(localized: "New Group")) },
                rename: store.renameTab,
                delete: { tab in
                    if selectedTabID == tab.id { selectedTabID = nil }
                    store.deleteTab(tab)
                }
            )

            // 现代 macOS 创作按钮：摒弃笨重的「+ 添加片段」工具条，采用轻量气泡图标。
            Button {
                startNewSnippet()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(store.tabs.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                    .background {
                        Circle()
                            .fill(Color.primary.opacity(0.05))
                    }
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .disabled(store.tabs.isEmpty)
            .help(Text("New Snippet"))
            .accessibilityLabel(Text("New Snippet"))
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    /// 片段卡片列表：无分割线，依靠微呼吸感卡片圆角与层级间距区分条目。
    private var snippetList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(tabItems) { item in
                    let isSelected = item.id == (draftID ?? selectedItem?.id)
                    FavoriteItemRow(
                        item: item,
                        isSelected: isSelected,
                        draftText: item.id == draftID ? editorText : nil
                    )
                    .onTapGesture { selectItem(item) }
                    .contextMenu {
                        if let text = item.plainText, !text.isEmpty {
                            Button("Copy to Clipboard") {
                                copyToClipboard(text)
                            }
                        }
                        Button("Remove from Favorites") {
                            removeFromFavorites(item)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.automatic)
    }

    /// 列表空状态：纯净优雅、垂直居中留白。
    private var emptyListState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: store.tabs.isEmpty ? "folder.badge.plus" : "note.text")
                .font(.system(size: 32, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text(store.tabs.isEmpty ? "Create a group first" : "No snippets yet")
                    .font(.system(size: 14, weight: .semibold))

                Text(
                    store.tabs.isEmpty
                        ? "Make a group with the + button, then add snippets here."
                        : "Add a snippet to save text you want to keep close."
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
            }

            if !store.tabs.isEmpty {
                Button {
                    startNewSnippet()
                } label: {
                    Label("New Snippet", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.top, 6)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 右侧正文画布（直接可读可写）

    @ViewBuilder
    private var detailCanvas: some View {
        if let item = selectedItem {
            if item.category.isTextual {
                // 文本与片段：去线留白，整个右侧即为直接可编辑的沉浸画布。
                SnippetEditor(
                    text: $editorText,
                    characterCount: editorText.count,
                    item: item,
                    allTabs: store.tabs,
                    onMoveTab: { newTab in
                        moveSnippet(item, to: newTab)
                    },
                    onRemove: {
                        removeFromFavorites(item)
                    }
                )
                .id(item.id)
            } else {
                // 非文本条目（图片/文件/链接）：保持优雅只读预览。
                nonTextDetail(item)
                    .id(item.id)
            }
        } else {
            ContentUnavailableView {
                Label("Nothing to preview", systemImage: "rectangle.dashed")
            } description: {
                Text("Select a snippet, or add a new one.")
            }
        }
    }

    private func nonTextDetail(_ item: HistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if let tab = item.favoriteTab {
                    groupMenuBadge(currentTab: tab, item: item)
                }

                Spacer(minLength: 8)

                Button(action: { removeFromFavorites(item) }) {
                    Image(systemName: "star.slash")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background {
                            Circle()
                                .fill(Color.primary.opacity(0.04))
                        }
                }
                .buttonStyle(.plain)
                .help(Text("Remove from Favorites"))
            }
            .padding(.horizontal, 28)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ScrollView {
                ClipPeekCard(
                    item: item,
                    onOpenInFinder: { openInFinder(item) },
                    onOpenInBrowser: { openInBrowser(item) },
                    onComposeEmail: { address in
                        if let url = EmailAddresses.mailtoURL(to: address) { NSWorkspace.shared.open(url) }
                    },
                    onConvertColor: { _ in }
                )
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
            }
        }
    }

    private func groupMenuBadge(currentTab: FavoriteTab, item: HistoryItem) -> some View {
        Menu {
            ForEach(store.tabs) { targetTab in
                Button {
                    moveSnippet(item, to: targetTab)
                } label: {
                    HStack {
                        Text(verbatim: targetTab.name)
                        if targetTab.id == currentTab.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                Text(verbatim: currentTab.name)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            }
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - 业务交互动作

    private func startNewSnippet() {
        guard let tab = selectedTab ?? store.tabs.first else { return }
        flushCurrentEdit()
        cleanupEmptyDraft(exempting: nil)

        let newItem = store.insertEmptySnippet(in: tab)
        draftID = newItem.id
        selectedID = newItem.id
        if selectedTabID != nil, selectedTabID != tab.id {
            selectedTabID = tab.id
        }
        editingItemID = newItem.id
        lastLoadedText = ""
        editorText = ""
    }

    private func selectItem(_ item: HistoryItem) {
        guard item.id != selectedID else { return }
        flushCurrentEdit()
        cleanupEmptyDraft(exempting: item.id)

        selectedID = item.id
        let text = item.plainText ?? ""
        editingItemID = item.id
        lastLoadedText = text
        editorText = text
    }

    private func selectTab(_ id: UUID?) {
        flushCurrentEdit()
        cleanupEmptyDraft(exempting: nil)

        selectedTabID = id
        selectedID = nil
        if let first = tabItems.first {
            selectedID = first.id
            let text = first.plainText ?? ""
            editingItemID = first.id
            lastLoadedText = text
            editorText = text
        } else {
            editingItemID = nil
            lastLoadedText = ""
            editorText = ""
        }
    }

    private func moveSnippet(_ item: HistoryItem, to newTab: FavoriteTab) {
        store.favorite(item, in: newTab)
        if selectedTabID != nil, selectedTabID != newTab.id {
            selectedTabID = newTab.id
        }
    }

    private func flushCurrentEdit() {
        guard let item = selectedItem, item.category.isTextual else { return }
        guard item.id == editingItemID else { return }
        if editorText != lastLoadedText {
            store.updateText(item, to: editorText)
            lastLoadedText = editorText
        }
    }

    private func cleanupEmptyDraft(exempting newID: UUID?) {
        guard let id = draftID, id != newID else { return }
        // 草稿是片段，不在 `items`（剪贴历史）里，需从全量里找。
        if let draftItem = store.allItems.first(where: { $0.id == id }),
           (draftItem.plainText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.delete(draftItem)
            if selectedID == id {
                selectedID = nil
            }
        }
        draftID = nil
    }

    private func removeFromFavorites(_ item: HistoryItem) {
        if draftID == item.id {
            draftID = nil
        }
        if selectedID == item.id {
            selectedID = nil
        }
        store.unfavorite(item)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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

// MARK: - 列表卡片组件（留白设计）

/// 列表卡片：呈现标题、正文轻量摘要、分类图标与时间。去线处理，以柔和外缘与呼吸感区分。
private struct FavoriteItemRow: View {
    let item: HistoryItem
    var isSelected: Bool = false
    var draftText: String? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    private var currentText: String {
        draftText ?? item.plainText ?? ""
    }

    private var title: String {
        let textTitle = currentText.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !textTitle.isEmpty { return textTitle }
        let itemTitle = ClipboardHistoryRow.title(of: item)
        return itemTitle.isEmpty ? String(localized: "New Snippet") : itemTitle
    }

    private var previewText: String? {
        let lines = currentText.split(separator: "\n", maxSplits: 2, omittingEmptySubsequences: true)
        if lines.count > 1 {
            return String(lines[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    var body: some View {
        let style = SiriGlassStyle.resolve(for: colorScheme)
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Image(systemName: item.category.symbolName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? AnyShapeStyle(style.iconForeground) : AnyShapeStyle(.secondary))
                    .frame(width: 18, height: 18)
                    .background {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isSelected ? AnyShapeStyle(style.iconBackground) : AnyShapeStyle(Color.primary.opacity(0.06)))
                    }
                    .accessibilityHidden(true)

                Text(verbatim: title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.primary.opacity(0.9)))
                    .italic(currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(item.lastCopiedAt, format: .relative(presentation: .named))
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
            }

            if let previewText, !previewText.isEmpty {
                Text(verbatim: previewText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.leading, 26)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? AnyShapeStyle(style.selection) : (isHovering ? AnyShapeStyle(Color.primary.opacity(0.04)) : AnyShapeStyle(.clear)))
        }
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - 详情画布组件（极致去线留白）

/// 详情正文画布：无边框、无沉陷凹槽，如同一张宁静的数字信纸。
struct SnippetEditor: View {
    @Binding var text: String
    let characterCount: Int
    var item: HistoryItem? = nil
    var allTabs: [FavoriteTab] = []
    var onMoveTab: ((FavoriteTab) -> Void)? = nil
    var onRemove: (() -> Void)? = nil
    var done: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部操作行：留白、轻盈，无横向分隔线
            HStack(spacing: 10) {
                if let item, let tab = item.favoriteTab, !allTabs.isEmpty {
                    groupMenuBadge(currentTab: tab)
                }

                Spacer(minLength: 8)

                // 一键复制按键：轻量微交互，复制后转为对勾反馈
                Button {
                    copySnippet()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .medium))
                        if isCopied {
                            Text("Copied")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .foregroundStyle(isCopied ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                    .padding(.horizontal, isCopied ? 8 : 6)
                    .frame(height: 26)
                    .background {
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    }
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .help(Text("Copy to Clipboard"))

                // 取消收藏按键
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .background {
                                Circle()
                                    .fill(Color.primary.opacity(0.05))
                            }
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .help(Text("Remove from Favorites"))
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 14)
            .padding(.bottom, 6)

            // 正文编辑画布：彻底抛弃 sunken gray well 与边框，纯净平铺于窗口表面
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Type or paste text here…")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .font(.system(size: 15))
                    .lineSpacing(6)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .accessibilityLabel(Text("Snippet"))
            }
            .padding(.horizontal, 26)
            .padding(.top, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // 底部元信息微标签
            HStack {
                Text("\(characterCount) characters")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 14)
        }
        .onAppear {
            if text.isEmpty {
                isFocused = true
            }
        }
    }

    private func groupMenuBadge(currentTab: FavoriteTab) -> some View {
        Menu {
            ForEach(allTabs) { targetTab in
                Button {
                    onMoveTab?(targetTab)
                } label: {
                    HStack {
                        Text(verbatim: targetTab.name)
                        if targetTab.id == currentTab.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                Text(verbatim: currentTab.name)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            }
        }
        .menuStyle(.borderlessButton)
    }

    private func copySnippet() {
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation(.snappy(duration: 0.2)) {
            isCopied = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
}
