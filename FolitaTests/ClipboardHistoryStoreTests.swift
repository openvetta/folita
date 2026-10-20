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

    private func makeStore(limit: Int = 500, clock: Clock = Clock()) throws -> ClipboardHistoryStore {
        let container = try ModelContainer(
            for: HistoryItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ClipboardHistoryStore(container: container, limit: { limit }, now: clock.advance)
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
