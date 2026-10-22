import Foundation
import Observation
import os
import SwiftData

/// 剪贴历史的唯一读写入口，负责去重、按条数上限淘汰，以及收藏夹分组。
/// 数据量最多数千条，直接在主 actor 上使用 mainContext（见 docs/adr/0002）。
@MainActor
@Observable
final class ClipboardHistoryStore {
    /// 按最近复制时间倒序。
    private(set) var items: [HistoryItem] = []

    /// 收藏分组，按 `order` 升序（见 docs/adr/0006）。
    private(set) var tabs: [FavoriteTab] = []

    /// mainContext 不持有 container，container 释放后 context 随即失效，必须由这里持有。
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private var context: ModelContext { container.mainContext }
    @ObservationIgnored private let limit: () -> Int
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let logger = Logger(subsystem: "app.folita.Folita", category: "history")

    /// 预设分组只在首次启动播种一次，之后与用户自建的分组完全平等。
    /// 具体名字由宿主按当前界面语言解析后传入，存储层不读全局设置。
    static let defaultTabTitles: [LocalizedStringResource] = ["Work", "Life"]

    /// 预设分组名字按指定语言解析（见 docs/adr/0006）。只在首次启动播种时调用，
    /// 写入后即成为普通用户数据，之后切换语言不再改名。
    static func defaultTabNames(locale: Locale) -> [String] {
        defaultTabTitles.map { title in
            var resource = title
            resource.locale = locale
            return String(localized: resource)
        }
    }

    /// `favoriteSettings` 非空时才播种预设分组：由它记住「已经播种过一次」，
    /// 否则用户删空分组后重启会被重新建回来。测试传空数组或 nil 以拿到无分组状态。
    init(
        container: ModelContainer,
        limit: @escaping () -> Int,
        now: @escaping () -> Date = Date.init,
        defaultTabNames: [String] = [],
        favoriteSettings: FavoriteSettings? = nil
    ) {
        self.container = container
        self.limit = limit
        self.now = now
        reload()
        if let favoriteSettings, !defaultTabNames.isEmpty, !favoriteSettings.hasSeededDefaultTabs {
            seedDefaultTabs(named: defaultTabNames)
            favoriteSettings.markDefaultTabsSeeded()
        }
    }

    /// 记录一次复制。内容与已有条目相同时只把那条移到最前，不新增。
    func record(_ clip: CapturedClip) {
        let date = now()
        let hash = HistoryItem.hash(of: clip.contents)
        if let existing = items.first(where: { $0.contentHash == hash }) {
            existing.lastCopiedAt = date
            existing.updatedAt = date
            if let source = clip.sourceBundleID {
                existing.sourceBundleID = source
            }
        } else {
            context.insert(HistoryItem(clip: clip, at: date))
        }
        enforceLimit()
    }

    /// 回填某条历史后把它移到最前。
    func touch(_ item: HistoryItem) {
        let date = now()
        item.lastCopiedAt = date
        item.updatedAt = date
        commit()
    }

    func delete(_ item: HistoryItem) {
        context.delete(item)
        commit()
    }

    /// 「删除全部」只清未收藏条目：收藏是用户主动保留的内容，不应被批量清理连带删除。
    /// 返回保留下来的收藏条数，供界面提示。
    @discardableResult
    func clearAll() -> Int {
        let kept = items.filter(\.isFavorited)
        for item in items where !item.isFavorited {
            context.delete(item)
        }
        commit()
        return kept.count
    }

    /// 超出保留条数时从最旧的开始删除；收藏条目既不占用上限也不被淘汰。
    /// 调小上限后也调用它立即生效。
    func enforceLimit() {
        let sorted = fetchAll()
        let evictable = sorted.filter { !$0.isFavorited }
        for item in evictable.dropFirst(max(limit(), 0)) {
            context.delete(item)
        }
        commit()
    }

    // MARK: 收藏

    /// 新建一条空白的文本收藏，作为「New Snippet」的就地编辑草稿。内容会随用户在详情栏
    /// 输入而由 `updateText` 覆盖；若用户没输入就离开，视图层会把它删掉。
    @discardableResult
    func insertEmptySnippet(in tab: FavoriteTab) -> HistoryItem {
        let date = now()
        let item = HistoryItem(
            clip: CapturedClip(contents: [ClipContent(type: .string, data: Data())], sourceBundleID: nil),
            at: date
        )
        context.insert(item)
        item.favoriteTab = tab
        item.favoritedAt = date
        item.updatedAt = date
        commit()
        return item
    }

    /// 就地改写一条文本收藏的内容：只保留纯文本一种格式，并一起刷新标题、分类与内容指纹。
    /// 允许写成空串（用户正在清空重写时），是否保留空条目由视图层决定。
    func updateText(_ item: HistoryItem, to text: String) {
        let data = Data(text.utf8)
        let type = ClipContent(type: .string, data: data).type.rawValue
        if let first = item.contents?.first {
            first.type = type
            first.value = data
            // 手动编辑后只留纯文本，避免旧富文本/HTML 残留让回填带上过期样式。
            for extra in (item.contents ?? []).dropFirst() { context.delete(extra) }
        } else {
            item.contents = [HistoryItemContent(type: type, value: data, order: 0)]
        }
        let contents = [ClipContent(type: .string, data: data)]
        item.title = ClipClassification.title(for: contents)
        item.categoryRaw = ClipClassification.category(of: contents).rawValue
        item.contentHash = HistoryItem.hash(of: contents)
        item.updatedAt = now()
        commit()
    }

    /// 收藏到指定分组；已在其他分组时直接改归属，并刷新收藏时间。
    func favorite(_ item: HistoryItem, in tab: FavoriteTab) {
        item.favoriteTab = tab
        item.favoritedAt = now()
        item.updatedAt = item.favoritedAt ?? item.updatedAt
        commit()
    }

    /// 取消收藏，条目退回普通历史。
    func unfavorite(_ item: HistoryItem) {
        item.favoriteTab = nil
        item.favoritedAt = nil
        item.updatedAt = now()
        commit()
    }

    /// 某个分组下的条目，按收藏时间倒序；重新复制一条已收藏内容不会改变它的位置。
    func items(in tab: FavoriteTab) -> [HistoryItem] {
        favorites.filter { $0.favoriteTab?.id == tab.id }
    }

    /// 全部分组的收藏条目，按收藏时间倒序。
    var favorites: [HistoryItem] {
        items
            .filter(\.isFavorited)
            .sorted { ($0.favoritedAt ?? .distantPast) > ($1.favoritedAt ?? .distantPast) }
    }

    @discardableResult
    func createTab(named name: String) -> FavoriteTab? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let tab = FavoriteTab(name: name, order: (tabs.map(\.order).max() ?? 0) + 1, at: now())
        context.insert(tab)
        commit()
        return tab
    }

    func renameTab(_ tab: FavoriteTab, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        tab.name = name
        commit()
    }

    /// 删除分组：组内条目退回普通历史，剪贴内容本身保留（不用级联）。返回退回的条数。
    @discardableResult
    func deleteTab(_ tab: FavoriteTab) -> Int {
        let affected = favorites.filter { $0.favoriteTab?.id == tab.id }
        let date = now()
        for item in affected {
            item.favoriteTab = nil
            item.favoritedAt = nil
            item.updatedAt = date
        }
        context.delete(tab)
        commit()
        return affected.count
    }

    private func seedDefaultTabs(named names: [String]) {
        let date = now()
        for (index, name) in names.enumerated() {
            context.insert(FavoriteTab(name: name, order: index + 1, at: date))
        }
        commit()
    }

    private func commit() {
        do {
            try context.save()
        } catch {
            logger.error("Saving history failed: \(error.localizedDescription, privacy: .public)")
        }
        reload()
    }

    private func reload() {
        items = fetchAll()
        tabs = fetchTabs()
    }

    private func fetchAll() -> [HistoryItem] {
        let descriptor = FetchDescriptor<HistoryItem>(sortBy: [SortDescriptor(\.lastCopiedAt, order: .reverse)])
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("Fetching history failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func fetchTabs() -> [FavoriteTab] {
        let descriptor = FetchDescriptor<FavoriteTab>(sortBy: [SortDescriptor(\.order)])
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("Fetching favorite tabs failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
