import AppKit
import SwiftUI

/// 主窗口的收藏夹分区：左侧条目列表（顶部一排分组胶囊），右侧详情。
///
/// 与面板里的收藏夹共用同一套数据（`ClipboardHistoryStore`）和同一个分组胶囊组件，
/// 只是宿主更宽、能看到完整详情，所以这里不做粘贴与快捷键，
/// 只提供「浏览 + 取消收藏 + 管理分组」。
///
/// 分组用横向胶囊而不是第二列列表：竖向两列列表在视觉上是重复的，
/// 而胶囊与面板里的收藏夹完全一致，用户在两处看到的是同一个东西。
struct FavoritesView: View {
    @Environment(ClipboardHistoryStore.self) private var store

    @State private var selectedID: UUID?
    @State private var selectedTabID: UUID?
    @State private var renamingTabID: UUID?
    @State private var renameDraft = ""

    private static let listColumnWidth: CGFloat = 280

    var body: some View {
        HStack(spacing: 0) {
            listColumn
                .frame(width: Self.listColumnWidth)
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

    // MARK: 列表栏

    private var listColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            FavoriteTabBar(
                tabs: store.tabs,
                selectedTabID: selectedTabID,
                renamingTabID: $renamingTabID,
                renameDraft: $renameDraft,
                // 换分组后选中项可能已不在列表里，交回给 selectedItem 兜底。
                select: { selectedTabID = $0 },
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

            if tabItems.isEmpty {
                emptyState
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
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "star")
                .font(.system(size: 26, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            Text("Nothing here yet")
                .font(.system(size: 13, weight: .semibold))
            Text("Favorite items appear here. Press ⌘F on an item in the clipboard panel and pick a group.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
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
