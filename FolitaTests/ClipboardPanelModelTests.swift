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
            for: HistoryItem.self, FavoriteTab.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        var tick = Date(timeIntervalSince1970: 0)
        store = ClipboardHistoryStore(container: container, limit: { 500 }, now: {
            tick.addTimeInterval(1)
            return tick
        }, defaultTabNames: [])
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

    /// Esc 逐层退：预览打开时先退出预览，再按一次才收起面板（与收藏夹同一套层级）。
    @Test func escapeClosesThePreviewBeforeThePanel() {
        var dismissed = false
        model.onDismiss = { dismissed = true }
        copy("a")
        model.perform(.peek)

        model.perform(.dismiss)
        #expect(model.isPeeking == false)
        #expect(dismissed == false)

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
        #expect(C.command(for: ",", modifiers: .command) == .openMainPanel)
        #expect(C.command(for: ",", modifiers: []) == nil)
        #expect(C.command(for: "1", modifiers: []) == nil)
        #expect(C.command(for: .delete, modifiers: []) == nil)
        #expect(C.command(for: .escape, modifiers: []) == .dismiss)
        #expect(C.command(for: .rightArrow, modifiers: []) == .peek)
        #expect(C.command(for: .leftArrow, modifiers: []) == .endPeek)
        // ⌘← 切收藏夹，⌘F 打开收藏选择器。
        #expect(C.command(for: .leftArrow, modifiers: .command) == .toggleFavorites)
        #expect(C.command(for: "f", modifiers: .command) == .toggleFavoritePicker)
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

    /// ⌘,：面板里的设置快捷键，先收起「更多操作」菜单再请求打开主面板。
    @Test func commandCommaOpensTheMainPanel() throws {
        copy("b", "a")
        var opened = 0
        model.onOpenMainPanel = { opened += 1 }
        let item = try #require(model.selectedItem)
        model.setRowFrame(CGRect(x: 24, y: 100, width: 392, height: 52), for: item.id)
        model.perform(.toggleActionsMenu)
        #expect(model.isShowingActionsMenu)

        model.perform(.openMainPanel)

        #expect(opened == 1)
        #expect(!model.isShowingActionsMenu)
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
                size: ClipboardPanelMetrics.actionsMenuSize(rowCount: 6, separatorCount: 2),
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

    // MARK: 收藏夹

    /// 常见流程：⌘F 收藏到「工作」→ ⌘← 进收藏夹 → 只看得到这条 → ↔切回列表。
    @Test func favoriteThenBrowseFavorites() throws {
        copy("draft", "groceries")
        let work = try #require(store.createTab(named: "Work"))
        let item = try #require(model.selectedItem)

        model.perform(.toggleFavoritePicker)
        #expect(model.isShowingFavoritePicker)
        #expect(model.highlightedFavoritePickerRow == .tab(work.id))

        model.activateFavoritePickerRow(.tab(work.id))
        #expect(model.isShowingFavoritePicker == false)
        #expect(item.isFavorited)
        #expect(model.selectedTabID == work.id)

        model.perform(.toggleFavorites)
        #expect(model.mode == .favorites)
        #expect(model.visibleItems.map(\.title) == ["groceries"])

        model.perform(.toggleFavorites)
        #expect(model.mode == .history)
        #expect(model.visibleItems.count == 2)
    }

    /// 收藏夹里的 ↑↓ 与删除照旧作用在列表上；删除的是整条剪贴。
    @Test func keyboardAndDeleteWorkInsideFavorites() throws {
        copy("c", "b", "a")
        let tab = try #require(store.createTab(named: "Work"))
        for item in store.items {
            store.favorite(item, in: tab)
        }
        // 按 store.items 顺序收藏，收藏时间递增，收藏夹因此倒序。
        model.perform(.toggleFavorites)
        #expect(model.visibleItems.map(\.title) == ["c", "b", "a"])

        model.perform(.moveDown)
        #expect(model.selectedItem?.title == "b")

        model.perform(.deleteSelected)
        #expect(store.items.map(\.title) == ["a", "c"])
        #expect(model.visibleItems.map(\.title) == ["c", "a"])
    }

    /// 收藏夹里按 Esc 逐层退：先关预览、再退出收藏夹、最后才收起面板。
    @Test func escapeBacksOutOneLayerAtATime() throws {
        var dismissed = false
        model.onDismiss = { dismissed = true }
        copy("a")
        let tab = try #require(store.createTab(named: "Work"))
        let item = try #require(model.selectedItem)
        store.favorite(item, in: tab)

        model.perform(.toggleFavorites)
        model.perform(.peek)
        #expect(model.mode == .favorites)
        #expect(model.isPeeking)

        model.perform(.dismiss)
        #expect(model.mode == .favorites)
        #expect(model.isPeeking == false)
        #expect(dismissed == false)

        model.perform(.dismiss)
        #expect(model.mode == .history)
        #expect(dismissed == false)

        model.perform(.dismiss)
        #expect(dismissed)
    }

    /// 收藏夹里可以预览：→ 进预览，⌘← 直接退出收藏夹。
    @Test func previewWorksInsideFavorites() throws {
        copy("a")
        let tab = try #require(store.createTab(named: "Work"))
        let item = try #require(model.selectedItem)
        store.favorite(item, in: tab)

        model.perform(.toggleFavorites)
        model.perform(.peek)
        #expect(model.isPeeking)

        model.perform(.toggleFavorites)
        #expect(model.mode == .history)
    }

    /// 换分组、取消收藏都走同一个选择器。
    @Test func pickerCanMoveAndUnfavorite() throws {
        copy("a")
        let work = try #require(store.createTab(named: "Work"))
        let life = try #require(store.createTab(named: "Life"))
        let item = try #require(model.selectedItem)
        store.favorite(item, in: work)

        model.perform(.toggleFavoritePicker)
        // 已收藏时最后多一行「取消收藏」。
        #expect(model.favoritePickerRows == [.tab(work.id), .tab(life.id), .unfavorite])
        #expect(model.highlightedFavoritePickerRow == .tab(work.id))

        model.activateFavoritePickerRow(.tab(life.id))
        #expect(item.favoriteTab?.id == life.id)

        model.perform(.toggleFavoritePicker)
        #expect(model.highlightedFavoritePickerRow == .tab(life.id))
        model.activateFavoritePickerRow(.unfavorite)
        #expect(item.isFavorited == false)
        #expect(store.favorites.isEmpty)
    }

    /// 没有分组时选择器只剩「新建分组…」，否则用户没地方收纳。
    @Test func pickerOffersCreateWhenNoTabsExist() {
        copy("a")
        #expect(store.tabs.isEmpty)

        model.perform(.toggleFavoritePicker)
        #expect(model.favoritePickerRows == [.createTab])

        model.confirmFavoritePickerSelection()
        #expect(store.tabs.count == 1)
        #expect(model.selectedItem?.isFavorited == true)
    }

    /// 选择器打开时 ↑↓ 只移动高亮，Esc 收起选择器且不退出收藏夹。
    @Test func pickerKeysAreModal() throws {
        copy("a")
        let work = try #require(store.createTab(named: "Work"))
        try #require(store.createTab(named: "Life"))
        let item = try #require(model.selectedItem)
        store.favorite(item, in: work)

        model.perform(.toggleFavorites)
        model.perform(.toggleFavoritePicker)
        #expect(model.highlightedFavoritePickerRow == .tab(try #require(store.tabs.first).id))

        model.perform(.moveDown)
        #expect(model.highlightedFavoritePickerRow == .tab(store.tabs[1].id))

        model.perform(.dismiss)
        #expect(model.isShowingFavoritePicker == false)
        #expect(model.mode == .favorites)
    }

    /// ⌘F 再按一次收起，不递归打开。
    @Test func commandFTogglesThePicker() {
        copy("a")
        model.perform(.toggleFavoritePicker)
        #expect(model.isShowingFavoritePicker)
        model.perform(.toggleFavoritePicker)
        #expect(model.isShowingFavoritePicker == false)
    }

    /// 列表为空时不开选择器（没有可收藏的条目）。
    @Test func pickerDoesNotOpenOnAnEmptyList() {
        model.perform(.toggleFavoritePicker)
        #expect(model.isShowingFavoritePicker == false)
    }

    /// 重新呼出面板总是回到剪贴列表，但记住上次选中的分组。
    @Test func presentationReturnsToHistoryButKeepsTheTab() throws {
        copy("a")
        let tab = try #require(store.createTab(named: "Work"))
        model.perform(.toggleFavorites)
        model.selectTab(tab.id)

        model.prepareForPresentation()
        #expect(model.mode == .history)
        #expect(model.selectedTabID == tab.id)
        #expect(model.isShowingFavoritePicker == false)
    }

    /// 收藏夹里选类型筛选是叠加的：只筛收藏项，不是筛全部历史。
    @Test func typeFilterNarrowsFavoritesOnly() throws {
        copy("meeting", "https://folita.app")
        let tab = try #require(store.createTab(named: "Work"))
        let link = try #require(model.selectedItem)
        store.favorite(link, in: tab)

        model.perform(.toggleFavorites)
        #expect(model.visibleItems.map(\.title) == ["https://folita.app"])

        // 链接在类型筛选里同时算文本，因此用「仅图片」验证筛选真的叠加在收藏项上。
        model.filter = .images
        #expect(model.visibleItems.isEmpty)

        model.filter = .links
        #expect(model.visibleItems.map(\.title) == ["https://folita.app"])
        #expect(store.items.count == 2)
    }

    /// 删除分组：条目退回普通历史，当前视图回到「全部」。
    @Test func deletingTheSelectedTabFallsBackToAll() throws {
        copy("a")
        let tab = try #require(store.createTab(named: "Work"))
        let item = try #require(model.selectedItem)
        store.favorite(item, in: tab)
        model.perform(.toggleFavorites)
        model.selectTab(tab.id)

        model.deleteTab(tab)
        #expect(model.selectedTabID == nil)
        #expect(model.visibleItems.isEmpty)
        #expect(store.items.map(\.title) == ["a"])
    }
}
