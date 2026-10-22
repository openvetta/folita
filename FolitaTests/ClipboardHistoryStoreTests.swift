import AppKit
import SwiftData
import Testing
@testable import Folita

@MainActor
struct ClipboardHistoryStoreTests {
    private final class Clock {
        var date = Date(timeIntervalSince1970: 1_000)
        func advance() -> Date {
            date.addTimeInterval(1)
            return date
        }
    }

    /// 默认不播种预设分组，需要分组时由用例自己创建。
    private func makeStore(limit: Int = 500, clock: Clock = Clock()) throws -> ClipboardHistoryStore {
        let container = try ModelContainer(
            for: HistoryItem.self, FavoriteTab.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ClipboardHistoryStore(
            container: container,
            limit: { limit },
            now: clock.advance,
            defaultTabNames: []
        )
    }

    private func clip(_ text: String, source: String? = "com.apple.TextEdit") -> CapturedClip {
        CapturedClip(contents: [ClipContent(type: .string, data: Data(text.utf8))], sourceBundleID: source)
    }

    @Test func recordsNewestFirstWithDerivedMetadata() throws {
        let store = try makeStore()
        store.record(clip("first"))
        store.record(clip("https://folita.app"))

        #expect(store.items.map(\.title) == ["https://folita.app", "first"])
        #expect(store.items.first?.category == .link)
        #expect(store.items.first?.sourceBundleID == "com.apple.TextEdit")
    }

    @Test func duplicateMovesExistingItemToTopInsteadOfAdding() throws {
        let store = try makeStore()
        store.record(clip("a"))
        store.record(clip("b"))
        let original = try #require(store.items.last)
        let firstCopiedAt = original.firstCopiedAt

        store.record(clip("a", source: "com.apple.Notes"))

        #expect(store.items.map(\.title) == ["a", "b"])
        #expect(store.items.first?.id == original.id)
        #expect(store.items.first?.firstCopiedAt == firstCopiedAt)
        #expect(store.items.first?.sourceBundleID == "com.apple.Notes")
    }

    @Test func preservesAllFormatsInOriginalOrder() throws {
        let store = try makeStore()
        let contents = [
            ClipContent(type: .string, data: Data("Bold".utf8)),
            ClipContent(type: .rtf, data: Data([1, 2, 3])),
            ClipContent(type: .html, data: Data("<b>Bold</b>".utf8)),
        ]
        store.record(CapturedClip(contents: contents, sourceBundleID: nil))

        #expect(store.items.first?.clipContents == contents)
        #expect(store.items.first?.category == .richText)
    }

    @Test func evictsOldestBeyondLimit() throws {
        let store = try makeStore(limit: 3)
        for text in ["1", "2", "3", "4", "5"] {
            store.record(clip(text))
        }
        #expect(store.items.map(\.title) == ["5", "4", "3"])
    }

    @Test func deleteTouchAndClearAll() throws {
        let store = try makeStore()
        store.record(clip("a"))
        store.record(clip("b"))
        store.record(clip("c"))

        let a = try #require(store.items.first { $0.title == "a" })
        store.touch(a)
        #expect(store.items.map(\.title) == ["a", "c", "b"])

        let c = try #require(store.items.first { $0.title == "c" })
        store.delete(c)
        #expect(store.items.map(\.title) == ["a", "b"])

        store.clearAll()
        #expect(store.items.isEmpty)
    }

    @Test func hashIgnoresFormatOrderButNotData() {
        let text = ClipContent(type: .string, data: Data("x".utf8))
        let rtf = ClipContent(type: .rtf, data: Data([1]))
        #expect(HistoryItem.hash(of: [text, rtf]) == HistoryItem.hash(of: [rtf, text]))
        #expect(HistoryItem.hash(of: [text]) != HistoryItem.hash(of: [ClipContent(type: .string, data: Data("y".utf8))]))
    }

    // MARK: 收藏夹

    /// 常见流程：收藏一条到「工作」→ 在收藏夹里看到它 → 取消收藏后退回普通历史。
    @Test func favoriteAndUnfavorite() throws {
        let store = try makeStore()
        let tab = try #require(store.createTab(named: "Work"))
        store.record(clip("draft"))
        let item = try #require(store.items.first)
        #expect(item.isFavorited == false)

        store.favorite(item, in: tab)

        #expect(item.isFavorited)
        #expect(store.favorites.map(\.title) == ["draft"])
        #expect(store.items(in: tab).map(\.title) == ["draft"])
        // 收藏不把条目从普通历史里拿出来。
        #expect(store.items.map(\.title) == ["draft"])

        store.unfavorite(item)
        #expect(item.isFavorited == false)
        #expect(store.favorites.isEmpty)
        #expect(store.items.map(\.title) == ["draft"])
    }

    /// 单选归属：换分组就是改归属，不产生两条收藏。
    @Test func favoritingAgainMovesTheItemToTheOtherTab() throws {
        let store = try makeStore()
        let work = try #require(store.createTab(named: "Work"))
        let life = try #require(store.createTab(named: "Life"))
        store.record(clip("a"))
        let item = try #require(store.items.first)

        store.favorite(item, in: work)
        store.favorite(item, in: life)

        #expect(store.items(in: work).isEmpty)
        #expect(store.items(in: life).map(\.title) == ["a"])
        #expect(store.favorites.count == 1)
    }

    /// 收藏夹按收藏时间倒序，与最近复制时间无关。
    @Test func favoritesSortByFavoritedTimeNotCopyTime() throws {
        let store = try makeStore()
        let tab = try #require(store.createTab(named: "Work"))
        store.record(clip("first"))
        store.record(clip("second"))
        let first = try #require(store.items.first { $0.title == "first" })
        let second = try #require(store.items.first { $0.title == "second" })

        store.favorite(first, in: tab)
        store.favorite(second, in: tab)
        #expect(store.items(in: tab).map(\.title) == ["second", "first"])

        // 重新复制已收藏内容：普通历史移到最前，收藏夹顺序不变。
        store.record(clip("first"))
        #expect(store.items.map(\.title).first == "first")
        #expect(store.items(in: tab).map(\.title) == ["second", "first"])
    }

    /// 删除分组只取消收藏，剪贴内容保留。
    @Test func deletingATabReturnsItsItemsToPlainHistory() throws {
        let store = try makeStore()
        let tab = try #require(store.createTab(named: "Work"))
        store.record(clip("a"))
        store.record(clip("b"))
        for item in store.items {
            store.favorite(item, in: tab)
        }

        let returned = store.deleteTab(tab)

        #expect(returned == 2)
        #expect(store.tabs.isEmpty)
        #expect(store.items.count == 2)
        #expect(store.favorites.isEmpty)
        #expect(store.items.allSatisfy { $0.isFavorited == false })
    }

    /// 收藏条目不占用保留条数，也不会被淘汰。
    @Test func favoritesSurviveRetentionLimit() throws {
        let store = try makeStore(limit: 2)
        let tab = try #require(store.createTab(named: "Work"))
        store.record(clip("keep"))
        let kept = try #require(store.items.first)
        store.favorite(kept, in: tab)

        for text in ["1", "2", "3"] {
            store.record(clip(text))
        }

        #expect(store.items.contains { $0.title == "keep" })
        // 未收藏的只留下最近两条。
        #expect(store.items.filter { !$0.isFavorited }.map(\.title) == ["3", "2"])
    }

    /// 把上限调到低于现有条数时，淘汰同样跳过收藏项。
    @Test func shrinkingTheLimitKeepsFavorites() throws {
        final class Limit {
            var value = 5
        }
        let limit = Limit()
        let container = try ModelContainer(
            for: HistoryItem.self, FavoriteTab.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ClipboardHistoryStore(container: container, limit: { limit.value }, defaultTabNames: [])
        let tab = try #require(store.createTab(named: "Work"))
        store.record(clip("keep"))
        let kept = try #require(store.items.first)
        store.favorite(kept, in: tab)
        for text in ["1", "2", "3"] {
            store.record(clip(text))
        }
        #expect(store.items.count == 4)

        limit.value = 1
        store.enforceLimit()

        #expect(store.items.contains { $0.title == "keep" })
        #expect(store.items.filter { !$0.isFavorited }.map(\.title) == ["3"])
    }

    /// 「删除全部」只清未收藏条目，并把保留条数返回给界面提示。
    @Test func clearAllKeepsFavorites() throws {
        let store = try makeStore()
        let tab = try #require(store.createTab(named: "Work"))
        store.record(clip("keep"))
        store.record(clip("gone"))
        let kept = try #require(store.items.first { $0.title == "keep" })
        store.favorite(kept, in: tab)

        let retained = store.clearAll()

        #expect(retained == 1)
        #expect(store.items.map(\.title) == ["keep"])
        #expect(store.favorites.map(\.title) == ["keep"])
    }

    /// 预设分组只在首次启动播种；用户删空后重启不会重建。
    @Test func defaultTabsAreSeededOnceAndNeverRecreated() throws {
        let suite = "FolitaTests.Favorite.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let container = try ModelContainer(
            for: HistoryItem.self, FavoriteTab.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let names = ["Work", "Life"]
        let store = ClipboardHistoryStore(
            container: container, limit: { 500 },
            defaultTabNames: names,
            favoriteSettings: FavoriteSettings(userDefaults: defaults)
        )
        #expect(store.tabs.map(\.name) == names)

        for tab in store.tabs {
            store.deleteTab(tab)
        }
        #expect(store.tabs.isEmpty)

        // 同一个库重新打开：播种标记已写入，不再重建。
        let reopened = ClipboardHistoryStore(
            container: container, limit: { 500 },
            defaultTabNames: names,
            favoriteSettings: FavoriteSettings(userDefaults: defaults)
        )
        #expect(reopened.tabs.isEmpty)
    }

    /// 空库 + 未播种过 → 播种；名字按宿主传入的语言解析结果写入。
    @Test func defaultTabsUseThePassedNames() throws {
        let suite = "FolitaTests.Favorite.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = ClipboardHistoryStore(
            container: try ModelContainer(
                for: HistoryItem.self, FavoriteTab.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ),
            limit: { 500 },
            defaultTabNames: ClipboardHistoryStore.defaultTabNames(locale: Locale(identifier: "zh-Hans")),
            favoriteSettings: FavoriteSettings(userDefaults: defaults)
        )
        #expect(store.tabs.map(\.name) == ["工作", "生活"])
    }

    @Test func createRenameAndRejectBlankTabNames() throws {
        let store = try makeStore()
        #expect(store.createTab(named: "   ") == nil)
        #expect(store.tabs.isEmpty)

        let tab = try #require(store.createTab(named: "  Ideas  "))
        #expect(tab.name == "Ideas")
        #expect(tab.order == 1)

        store.renameTab(tab, to: "Reading")
        #expect(store.tabs.map(\.name) == ["Reading"])

        store.renameTab(tab, to: "  ")
        #expect(store.tabs.map(\.name) == ["Reading"])
    }

    /// 新分组追加在末尾。
    @Test func newTabsAppendInCreationOrder() throws {
        let store = try makeStore()
        for name in ["A", "B", "C"] {
            store.createTab(named: name)
        }
        #expect(store.tabs.map(\.name) == ["A", "B", "C"])
    }

    // MARK: 手动添加 / 编辑片段

    /// 常见流程：新建空白片段 → 写入文本 → 成为该分组的收藏，标题与分类随内容更新。
    @Test func insertEmptySnippetThenUpdateText() throws {
        let store = try makeStore()
        let work = try #require(store.createTab(named: "Work"))

        let item = store.insertEmptySnippet(in: work)
        #expect(item.isFavorited)
        #expect(item.favoriteTab?.id == work.id)
        #expect(item.title.isEmpty)

        store.updateText(item, to: "hello world")

        #expect(item.title == "hello world")
        #expect(item.category == .text)
        #expect(item.clipContents == [ClipContent(type: .string, data: Data("hello world".utf8))])
        // 普通历史里也有它，且收藏分组能筛到。
        #expect(store.items.map(\.title) == ["hello world"])
        #expect(store.items(in: work).map(\.title) == ["hello world"])
    }

    /// 首尾空白原样保留（代码缩进）；改短或清空后标题随之更新。
    @Test func updateTextKeepsWhitespaceAndRetitles() throws {
        let store = try makeStore()
        let tab = try #require(store.createTab(named: "Work"))
        let item = store.insertEmptySnippet(in: tab)

        let padded = "  line\n    indented"
        store.updateText(item, to: padded)
        #expect(item.clipContents == [ClipContent(type: .string, data: Data(padded.utf8))])

        store.updateText(item, to: "")
        #expect(item.title.isEmpty)
        #expect(item.clipContents == [ClipContent(type: .string, data: Data())])
    }

    /// 编辑后只保留纯文本一种格式，旧的富文本残留会被清掉，避免回填带出过期样式。
    @Test func updateTextDropsOtherFormats() throws {
        let store = try makeStore()
        let tab = try #require(store.createTab(named: "Work"))
        let contents = [
            ClipContent(type: .string, data: Data("Bold".utf8)),
            ClipContent(type: .rtf, data: Data([1, 2, 3])),
            ClipContent(type: .html, data: Data("<b>Bold</b>".utf8)),
        ]
        store.record(CapturedClip(contents: contents, sourceBundleID: nil))
        let item = try #require(store.items.first)
        store.favorite(item, in: tab)

        store.updateText(item, to: "plain")

        #expect(item.clipContents == [ClipContent(type: .string, data: Data("plain".utf8))])
        #expect(item.category == .text)
        #expect(item.title == "plain")
    }

    /// 手动新建的片段同样不会被条数上限淘汰（收藏语义与复制来源一致）。
    @Test func snippetSurvivesRetentionLimit() throws {
        let store = try makeStore(limit: 1)
        let tab = try #require(store.createTab(named: "Work"))
        let item = store.insertEmptySnippet(in: tab)
        store.updateText(item, to: "keep")
        for text in ["1", "2", "3"] {
            store.record(clip(text))
        }
        #expect(store.favorites.map(\.title) == ["keep"])
    }
}

@MainActor
struct HistorySettingsTests {
    private func makeIsolatedDefaults() -> UserDefaults {
        let suite = "FolitaTests.History.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func defaultsTo500AndPersistsChoice() {
        let defaults = makeIsolatedDefaults()
        let settings = HistorySettings(userDefaults: defaults)
        #expect(settings.limit == 500)

        settings.limit = 1_000
        #expect(HistorySettings(userDefaults: defaults).limit == 1_000)
    }

    @Test func ignoresUnsupportedSavedValue() {
        let defaults = makeIsolatedDefaults()
        defaults.set(42, forKey: HistorySettings.limitKey)
        #expect(HistorySettings(userDefaults: defaults).limit == HistorySettings.defaultLimit)
    }
}
