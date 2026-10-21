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
        let count = model.presentationCount
        model.prepareForPresentation()
        #expect(model.query.isEmpty)
        #expect(model.filter == .links)
        #expect(model.presentationCount == count + 1)
    }

    @Test func escapeDismisses() {
        var dismissed = false
        model.onDismiss = { dismissed = true }
        model.perform(.dismiss)
        #expect(dismissed)
    }

    // MARK: 详情预览

    /// 常见流程：→ 进入预览 → ↓↑ 切换条目（预览保持打开、详情跟着选中项）→ ← 退出。
    @Test func arrowKeysBrowseWhilePeekingAndLeftArrowCloses() {
        var changes: [Bool] = []
        model.onPeekChange = { changes.append($0) }
        copy("c", "b", "a")

        model.perform(.peek)
        #expect(model.isPeeking)
        #expect(model.selectedItem?.title == "a")

        model.perform(.moveDown)
        #expect(model.isPeeking)
        #expect(model.selectedItem?.title == "b")

        model.perform(.moveDown)
        model.perform(.moveUp)
        #expect(model.isPeeking)
        #expect(model.selectedItem?.title == "b")

        // 已在预览时再按 → 不重复通知窗口加宽。
        model.perform(.peek)
        model.perform(.endPeek)
        #expect(model.isPeeking == false)
        #expect(model.selectedItem?.title == "b")
        #expect(changes == [true, false])
    }

    /// 搜索、筛选、删除只改变右侧显示的条目，不退出预览。
    @Test func changingTheListKeepsPeekOpen() {
        copy("apple", "banana", "cherry")
        model.perform(.peek)

        model.query = "an"
        #expect(model.isPeeking)
        #expect(model.selectedItem?.title == "banana")

        model.query = "zzz"
        #expect(model.isPeeking)
        #expect(model.selectedItem == nil)

        model.query = ""
        model.perform(.deleteSelected)
        #expect(model.isPeeking)
        #expect(model.selectedItem?.title == "banana")

        model.filter = .text
        #expect(model.isPeeking)
    }

    @Test func escapeDismissesEvenWhilePeeking() {
        var dismissed = false
        model.onDismiss = { dismissed = true }
        copy("a")
        model.perform(.peek)
        model.perform(.dismiss)
        #expect(dismissed)
    }

    @Test func returnWhilePeekingPastesTheSelectedItem() {
        copy("b", "a")
        model.perform(.peek)
        model.perform(.moveDown)
        model.perform(.paste(.original))
        #expect(pasted.calls.map(\.0) == ["b"])
    }

    /// 每次呼出面板都从普通列表开始。
    @Test func presentationEndsPeek() {
        copy("a")
        model.perform(.peek)
        model.prepareForPresentation()
        #expect(model.isPeeking == false)
    }

    @Test func peekOnEmptyListDoesNothing() {
        model.perform(.peek)
        #expect(model.isPeeking == false)
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
        #expect(C.command(for: .escape, modifiers: []) == .dismiss)
        #expect(C.command(for: .rightArrow, modifiers: []) == .peek)
        #expect(C.command(for: .leftArrow, modifiers: []) == .endPeek)
        #expect(C.command(for: .rightArrow, modifiers: .command) == nil)
        #expect(C.command(for: .leftArrow, modifiers: .shift) == nil)
        // 大写锁定等非组合修饰键不影响判断。
        #expect(C.command(for: .return, modifiers: [.capsLock]) == .paste(.original))
    }
}
