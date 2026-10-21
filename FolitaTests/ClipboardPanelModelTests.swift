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
    /// ⌥↩ 走的是另一条不收起面板的路径，单独记录。
    private let kept: Box

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
        let kept = Box()
        self.kept = kept
        let pasted = Box()
        self.pasted = pasted
        model.onPaste = { item, mode in pasted.calls.append((item.title, mode)) }
        model.onPasteKeepingPanelOpen = { item, mode in kept.calls.append((item.title, mode)) }
        model.targetAppNameProvider = { "Safari" }
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
        #expect(C.command(for: .return, modifiers: .option) == .pasteKeepingPanelOpen)
        #expect(C.command(for: "x", modifiers: .control) == .deleteSelected)
        #expect(C.command(for: "x", modifiers: [.control, .shift]) == .deleteAll)
        #expect(C.command(for: "k", modifiers: .command) == .toggleActionsMenu)
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

    // MARK: 更多操作

    /// ⌥↩ 粘贴但保持面板打开：走的是不收起面板的那条回调，不会触发普通粘贴。
    @Test func optionReturnPastesWithoutClosingThePanel() {
        copy("b", "a")
        model.perform(.moveDown)
        model.perform(.pasteKeepingPanelOpen)

        #expect(kept.calls.map(\.0) == ["b"])
        #expect(pasted.calls.isEmpty)
    }

    @Test func deleteAllClearsHistoryAndSelection() {
        copy("c", "b", "a")
        model.perform(.deleteAll)

        #expect(store.items.isEmpty)
        #expect(model.visibleItems.isEmpty)
        #expect(model.selectedItem == nil)
    }

    /// ⌘K 打开、再按收起；菜单锚在选中条目上，用它的行位置算出卡片位置。
    @Test func commandKAnchorsTheMenuToTheSelectedItem() throws {
        copy("c", "b", "a")
        let item = try #require(model.selectedItem)
        let row = CGRect(x: 24, y: 100, width: 392, height: 52)
        model.setRowFrame(row, for: item.id)

        model.perform(.toggleActionsMenu)
        #expect(model.isShowingActionsMenu)
        #expect(model.actionsMenuItemID == item.id)
        #expect(
            model.actionsMenuFrame == ClipboardPanelMetrics.actionsMenuFrame(
                anchoredTo: row,
                entryCount: ClipboardActionsMenuEntry.allCases.count,
                in: CGRect(origin: .zero, size: ClipboardPanelMetrics.containerSize(isPeeking: false))
            )
        )

        model.perform(.toggleActionsMenu)
        #expect(model.isShowingActionsMenu == false)
        #expect(model.actionsMenuFrame == nil)
    }

    /// 还没量到行位置时菜单不出现，避免卡片闪在错误的位置。
    @Test func menuWaitsForTheRowGeometry() {
        copy("a")
        model.perform(.toggleActionsMenu)
        #expect(model.actionsMenuFrame == nil)
    }

    @Test func menuDoesNotOpenOnAnEmptyList() {
        model.perform(.toggleActionsMenu)
        #expect(model.isShowingActionsMenu == false)
    }

    /// 右键先选中被点的那一条，再把菜单锚在它上面。
    @Test func showActionsSelectsTheClickedItem() {
        copy("c", "b", "a")
        let oldest = model.visibleItems[2]

        model.showActions(for: oldest)
        #expect(model.selectedItem?.id == oldest.id)
        #expect(model.actionsMenuItemID == oldest.id)

        model.hideActions()
        #expect(model.isShowingActionsMenu == false)
    }

    /// 菜单打开时 ↑↓ 只移动菜单高亮，不切换列表选中项；不经过菜单的命令先收起菜单再执行。
    @Test func menuKeysDriveTheMenuNotTheList() {
        copy("c", "b", "a")
        let selected = model.selectedItem?.id
        model.perform(.toggleActionsMenu)

        model.perform(.moveDown)
        #expect(model.selectedItem?.id == selected)
        #expect(model.highlightedActionsMenuEntry == .pasteKeepingPanelOpen)

        model.perform(.moveUp)
        #expect(model.highlightedActionsMenuEntry == .pasteToTarget)

        for command in [ClipboardPanelCommand.peek, .deleteSelected, .paste(.plainText)] {
            if !model.isShowingActionsMenu { model.perform(.toggleActionsMenu) }
            model.perform(command)
            #expect(model.isShowingActionsMenu == false)
        }
    }

    /// Esc 先收起菜单，再按一次才收起面板。
    @Test func escapeClosesTheMenuBeforeThePanel() {
        var dismissed = false
        model.onDismiss = { dismissed = true }
        copy("a")

        model.perform(.toggleActionsMenu)
        model.perform(.dismiss)
        #expect(model.isShowingActionsMenu == false)
        #expect(dismissed == false)

        model.perform(.dismiss)
        #expect(dismissed)
    }

    @Test func newPanelPresentationClosesTheMenuAndSnapshotsTheTargetApp() {
        copy("a")
        model.perform(.toggleActionsMenu)
        model.prepareForPresentation()

        #expect(model.isShowingActionsMenu == false)
        #expect(model.targetAppName == "Safari")
    }

    @Test func hitTestFindsTheRowUnderThePoint() {
        copy("c", "b", "a")
        let items = model.visibleItems
        model.setRowFrame(CGRect(x: 24, y: 100, width: 392, height: 52), for: items[0].id)
        model.setRowFrame(CGRect(x: 24, y: 156, width: 392, height: 52), for: items[1].id)

        #expect(model.item(at: CGPoint(x: 30, y: 104))?.id == items[0].id)
        #expect(model.item(at: CGPoint(x: 400, y: 200))?.id == items[1].id)
        // 行间空隙与列表外不命中。
        #expect(model.item(at: CGPoint(x: 100, y: 152)) == nil)
        #expect(model.item(at: CGPoint(x: 100, y: 400)) == nil)
    }
}
