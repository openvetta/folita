import AppKit
import SwiftUI

/// 主窗口的收藏夹分区：左侧分组、中间条目、右侧详情。
///
/// 与面板里的收藏夹共用同一套数据（`ClipboardHistoryStore`），只是宿主更宽、能看到完整详情，
/// 所以这里不做粘贴与快捷键，只提供「浏览 + 取消收藏 + 管理分组」。
/// 外层 `MainPanelView` 已经是两栏 `NavigationSplitView`，这里改用固定三栏，
/// 避免嵌套 `NavigationSplitView` 让侧边栏出现两层。
struct FavoritesView: View {
    @Environment(ClipboardHistoryStore.self) private var store

    @State private var selectedID: UUID?
    @State private var selectedTabID: UUID?
    @State private var renamingTabID: UUID?
    @State private var renameDraft = ""

    private static let tabColumnWidth: CGFloat = 180
    private static let itemColumnWidth: CGFloat = 260

    var body: some View {
        HStack(spacing: 0) {
            tabColumn
                .frame(width: Self.tabColumnWidth)
            Divider()
            itemColumn
                .frame(width: Self.itemColumnWidth)
            Divider()
            detail
                .frame(maxWidth: .infinity)
        }
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

    // MARK: 分组

    private var tabColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: $selectedTabID) {
                Label {
                    Text("All")
                } icon: {
                    Image(systemName: "star")
                }
                .tag(UUID?.none)

                ForEach(store.tabs) { tab in
                    tabRow(tab)
                }
            }
            .listStyle(.sidebar)

            Divider()
            Button {
                if let tab = store.createTab(named: String(localized: "New Group")) {
                    renameDraft = tab.name
                    renamingTabID = tab.id
                }
            } label: {
                Label("New Group", systemImage: "plus")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
    }

    @ViewBuilder
    private func tabRow(_ tab: FavoriteTab) -> some View {
        if renamingTabID == tab.id {
            TextField("Group Name", text: $renameDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit { commitRename(tab) }
                .onExitCommand { renamingTabID = nil }
        } else {
            Label {
                Text(verbatim: tab.name)
            } icon: {
                Image(systemName: "folder")
            }
            .tag(UUID?.some(tab.id))
            .contextMenu {
                Button("Rename") {
                    renameDraft = tab.name
                    renamingTabID = tab.id
                }
                Button("Delete Group", role: .destructive) {
                    if selectedTabID == tab.id { selectedTabID = nil }
                    store.deleteTab(tab)
                }
            }
        }
    }

    private func commitRename(_ tab: FavoriteTab) {
        store.renameTab(tab, to: renameDraft)
        renamingTabID = nil
    }

    // MARK: 条目

    @ViewBuilder
    private var itemColumn: some View {
        if tabItems.isEmpty {
            ContentUnavailableView {
                Label("Nothing here yet", systemImage: "star")
            } description: {
                Text("Favorite items appear here. Press ⌘F on an item in the clipboard panel and pick a group.")
            }
        } else {
            List(tabItems, selection: $selectedID) { item in
                FavoriteItemRow(item: item)
                    .tag(item.id)
                    .contextMenu {
                        Button("Remove from Favorites") { store.unfavorite(item) }
                    }
            }
            .listStyle(.inset)
        }
    }

    // MARK: 详情

    @ViewBuilder
    private var detail: some View {
        if let item = selectedItem {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(verbatim: ClipboardHistoryRow.title(of: item))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Button("Remove from Favorites", systemImage: "star.slash") {
                        store.unfavorite(item)
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
        } else {
            ContentUnavailableView {
                Label("Nothing to preview", systemImage: "rectangle.dashed")
            }
        }
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

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.category.symbolName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 22)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: ClipboardHistoryRow.title(of: item))
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(item.lastCopiedAt, format: .relative(presentation: .named))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
