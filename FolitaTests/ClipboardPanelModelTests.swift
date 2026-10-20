import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct ClipboardPanelModelTests {
    private let store: ClipboardHistoryStore
    private let model: ClipboardPanelModel
    private let pasted: Box

    final class Box {
        var calls: [(String, PasteMode)] = []
    }

    init() throws {
        let container = try ModelContainer(
            for: HistoryItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        var tick = Date(timeIntervalSince1970: 0)
        store = ClipboardHistoryStore(container: container, limit: { 500 }, now: {
            tick.addTimeInterval(1)
            return tick
        })
        model = ClipboardPanelModel(store: store)
        let pasted = Box()
        self.pasted = pasted
        model.onPaste = { item, mode in pasted.calls.append((item.title, mode)) }
    }

    /// 依次复制，最后复制的排在最前。
    private func copy(_ texts: String...) {
        for text in texts {
            store.record(CapturedClip(contents: [ClipContent(type: .string, data: Data(text.utf8))], sourceBundleID: nil))
        }
    }

    private var visibleTitles: [String] { model.visibleItems.map(\.title) }

    @Test func searchAndFilterCombine() {
        copy("Meeting notes", "https://notes.example.com", "#FF0000", "groceries")

        model.query = "NOTES"
        #expect(visibleTitles == ["https://notes.example.com", "Meeting notes"])

        model.filter = .links
        #expect(visibleTitles == ["https://notes.example.com"])

        model.query = ""
        model.filter = .colors
        #expect(visibleTitles == ["#FF0000"])

        model.filter = .text
        #expect(visibleTitles.count == 4)
    }

    @Test func keyboardNavigationStaysWithinBounds() {
        copy("c", "b", "a")
        #expect(model.selectedItem?.title == "a")

        model.perform(.moveUp)
        #expect(model.selectedItem?.title == "a")

        model.perform(.moveDown)
        model.perform(.moveDown)
        model.perform(.moveDown)
        #expect(model.selectedItem?.title == "c")
    }

    @Test func selectionFollowsItemWhenNewCopiesArrive() {
        copy("b", "a")
        model.perform(.moveDown)
        #expect(model.selectedItem?.title == "b")

        copy("new")
        #expect(model.selectedItem?.title == "b")
    }

    @Test func typingResetsSelectionToFirstMatch() {
        copy("apple pie", "banana", "apple juice")
        model.perform(.moveDown)
        model.query = "apple"
        #expect(model.selectedItem?.title == "apple juice")
    }

    @Test func pasteCommandsUseSelectionOrIndex() {
        copy("c", "b", "a")
        model.perform(.moveDown)
        model.perform(.paste(.original))
        model.perform(.paste(.plainText))
        model.perform(.pasteAt(2))
        model.perform(.pasteAt(8))

        #expect(pasted.calls.map(\.0) == ["b", "b", "c"])
        #expect(pasted.calls.map(\.1) == [.original, .plainText, .original])
    }

    @Test func deleteSelectsNeighbor() {
        copy("c", "b", "a")
        model.perform(.moveDown)
        model.perform(.deleteSelected)
        #expect(visibleTitles == ["a", "c"])
        #expect(model.selectedItem?.title == "c")

        model.perform(.deleteSelected)
        #expect(model.selectedItem?.title == "a")
    }

    @Test func presentationClearsSearchButKeepsFilter() {
        copy("b", "https://a.com")
        model.filter = .links
        model.query = "a"
        model.prepareForPresentation()
        #expect(model.query.isEmpty)
        #expect(model.filter == .links)
    }

    @Test func keyMapping() {
        typealias C = ClipboardPanelCommand
        #expect(C.command(for: .upArrow, modifiers: []) == .moveUp)
        #expect(C.command(for: .downArrow, modifiers: []) == .moveDown)
        #expect(C.command(for: .return, modifiers: []) == .paste(.original))
        #expect(C.command(for: .return, modifiers: .shift) == .paste(.plainText))
        #expect(C.command(for: .delete, modifiers: .command) == .deleteSelected)
        #expect(C.command(for: "1", modifiers: .command) == .pasteAt(0))
        #expect(C.command(for: "9", modifiers: .command) == .pasteAt(8))
        #expect(C.command(for: "0", modifiers: .command) == nil)
        #expect(C.command(for: "1", modifiers: []) == nil)
        #expect(C.command(for: .delete, modifiers: []) == nil)
        // 大写锁定等非组合修饰键不影响判断。
        #expect(C.command(for: .return, modifiers: [.capsLock]) == .paste(.original))
    }
}
