import AppKit
import SwiftUI
import Testing
@testable import Folita

/// 链接、邮箱、颜色条目的专属操作：识别规则、更多操作菜单、详情按钮与粘贴转换结果。
@MainActor
struct ContentActionsTests {
    nonisolated private static let appearances: [(String, ColorScheme)] = [
        ("zh-Hans", .light), ("zh-Hans", .dark), ("en", .light), ("en", .dark),
    ]

    private static let blue = RGBAColor(parsing: "#1E90FF")!

    private func details(_ text: String) -> ClipDetails {
        let contents = [ClipContent(type: .string, data: Data(text.utf8))]
        return ClipDetails(contents: contents, category: ClipClassification.category(of: contents))
    }

    // MARK: 菜单条目

    @Test func menuEntriesFollowTheItemContent() {
        #expect(ClipboardActionsMenuEntry.entries(for: details("plain")) == [
            .pasteToTarget, .pasteKeepingPanelOpen, .pasteAsPlainText, .deleteEntry, .deleteAll,
        ])
        #expect(ClipboardActionsMenuEntry.entries(for: details("https://folita.app")).contains(.openInBrowser))
        #expect(ClipboardActionsMenuEntry.entries(for: details("a@x.com")).contains(.sendEmail(addresses: ["a@x.com"])))
        #expect(ClipboardActionsMenuEntry.entries(for: details("#1E90FF")).contains(.convertColor(Self.blue, excluding: .hex)))

        // 单个邮箱直接发送，多个邮箱才有二级菜单；颜色转换不含当前格式。
        #expect(ClipboardActionsMenuEntry.sendEmail(addresses: ["a@x.com"]).children.isEmpty)
        #expect(ClipboardActionsMenuEntry.sendEmail(addresses: ["a@x.com"]).command == .composeEmail("a@x.com"))
        #expect(ClipboardActionsMenuEntry.sendEmail(addresses: ["a@x.com", "b@y.org"]).children
            == [.sendEmailTo("a@x.com"), .sendEmailTo("b@y.org")])
        // 二级条目直接写出转换后的色值。
        #expect(ClipboardActionsMenuEntry.convertColor(Self.blue, excluding: .rgb).children == [
            .convertTo(.hex, text: "#1E90FF"), .convertTo(.hsl, text: "hsl(210, 100%, 56%)"),
        ])
        #expect(ClipboardActionsMenuEntry.convertTo(.rgb, text: "rgb(30, 144, 255)").title(targetAppName: nil)
            == .verbatim("rgb(30, 144, 255)"))
    }

    @Test func expandedChildrenFollowTheirParentAndShareItsGroup() {
        let entries = ClipboardActionsMenuEntry.entries(for: details("a@x.com b@y.org"))
        let parent = ClipboardActionsMenuEntry.sendEmail(addresses: ["a@x.com", "b@y.org"])
        let collapsed = ClipboardActionsMenuRow.rows(of: entries, expanded: nil)
        let expanded = ClipboardActionsMenuRow.rows(of: entries, expanded: parent)

        #expect(expanded.count == collapsed.count + 2)
        let index = expanded.firstIndex { $0.entry == parent }!
        #expect(expanded[index + 1].entry == .sendEmailTo("a@x.com") && expanded[index + 1].depth == 1)
        // 粘贴 / 针对内容 / 删除三组，两道分割线，展开不增加分割线。
        #expect(ClipboardActionsMenuRow.separatorCount(in: collapsed) == 2)
        #expect(ClipboardActionsMenuRow.separatorCount(in: expanded) == 2)
    }

    @Test(arguments: appearances)
    func menuAndSubmenuLayOutAtTheComputedSizes(locale: String, scheme: ColorScheme) {
        let entries = ClipboardActionsMenuEntry.entries(for: details("a@x.com b@y.org"))
        let parent = ClipboardActionsMenuEntry.sendEmail(addresses: ["a@x.com", "b@y.org"])
        let rows = ClipboardActionsMenuRow.rows(of: entries, expanded: parent)
        let top = rows.filter { $0.depth == 0 }
        let children = rows.filter { $0.depth == 1 }
        let menuSize = ClipboardPanelMetrics.actionsMenuSize(
            rowCount: top.count, separatorCount: ClipboardActionsMenuRow.separatorCount(in: top)
        )
        let submenuSize = ClipboardPanelMetrics.actionsSubmenuFrame(
            besides: CGRect(origin: .zero, size: menuSize), parentRowOffset: 0, rowCount: children.count,
            in: CGRect(x: -1000, y: -1000, width: 3000, height: 3000)
        ).size

        func fit<V: View>(_ view: V, width: CGFloat) -> CGSize {
            let host = NSHostingView(
                rootView: view.frame(width: width)
                    .environment(\.locale, Locale(identifier: locale))
                    .environment(\.colorScheme, scheme)
            )
            host.layoutSubtreeIfNeeded()
            return host.fittingSize
        }
        #expect(fit(ClipboardActionsMenuView(
            rows: top, targetAppName: "Safari", highlighted: parent, expanded: parent, activate: { _ in }
        ), width: menuSize.width) == menuSize)
        #expect(fit(ClipboardActionsSubmenuView(
            rows: children, highlighted: nil, activate: { _ in }
        ), width: submenuSize.width) == submenuSize)
    }

    /// 二级菜单放在一级卡片旁边，第一行与父行对齐，整张都在容器内。
    @Test func submenuSitsBesideTheMenuAlignedWithItsParentRow() {
        let container = CGRect(origin: .zero, size: ClipboardPanelMetrics.containerSize(isPeeking: true))
        let menu = CGRect(x: 100, y: 120, width: ClipboardPanelMetrics.actionsMenuWidth, height: 190)
        let offset = ClipboardPanelMetrics.actionsMenuRowOffset(index: 3, separatorsBefore: 1)

        // 右侧放得下：贴在右边，宽度是理想宽度。
        let right = ClipboardPanelMetrics.actionsSubmenuFrame(besides: menu, parentRowOffset: offset, rowCount: 2, in: container)
        #expect(right.minX == menu.maxX + ClipboardPanelMetrics.actionsSubmenuGap)
        #expect(right.width == ClipboardPanelMetrics.actionsSubmenuWidth)
        #expect(right.minY == menu.minY + offset - ClipboardPanelMetrics.actionsMenuPadding)
        #expect(container.contains(right))

        // 右侧放不下改放左侧，宽度随空间收窄但不小于最小宽度。
        let narrow = CGRect(origin: .zero, size: ClipboardPanelMetrics.containerSize)
        let rightEdge = CGRect(x: 168, y: 120, width: ClipboardPanelMetrics.actionsMenuWidth, height: 190)
        let left = ClipboardPanelMetrics.actionsSubmenuFrame(besides: rightEdge, parentRowOffset: offset, rowCount: 2, in: narrow)
        #expect(left.maxX == rightEdge.minX - ClipboardPanelMetrics.actionsSubmenuGap)
        #expect(left.width >= ClipboardPanelMetrics.actionsSubmenuMinWidth)
        #expect(narrow.contains(left))

        // 靠近底部时向上夹，不越出容器。
        let low = ClipboardPanelMetrics.actionsSubmenuFrame(
            besides: CGRect(x: 100, y: 400, width: 264, height: 190), parentRowOffset: 170, rowCount: 3, in: container
        )
        #expect(low.maxY <= container.maxY - ClipboardPanelMetrics.actionsMenuInset)
    }

    /// 展开后的卡片很高时，上下都放不下也整张留在容器内。
    @Test func tallMenuStaysInsideTheContainer() {
        let container = CGRect(origin: .zero, size: ClipboardPanelMetrics.containerSize)
        let size = ClipboardPanelMetrics.actionsMenuSize(rowCount: 12, separatorCount: 2)
        let frame = ClipboardPanelMetrics.actionsMenuFrame(
            anchoredTo: CGRect(x: 24, y: 280, width: 392, height: 52), size: size, in: container
        )
        #expect(frame.minY >= container.minY + ClipboardPanelMetrics.actionsMenuInset)
        #expect(frame.maxY <= container.maxY - ClipboardPanelMetrics.actionsMenuInset)
    }

    // MARK: 常见流程

    private func key(_ characters: String, _ flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil,
            characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: 0
        ))
    }

    private func openMenu(model: ClipboardPanelModel) throws -> ClipboardPanelController {
        model.setRowFrame(CGRect(x: 24, y: 88, width: 392, height: 52), for: try #require(model.selectedItem).id)
        let controller = ClipboardPanelController(model: model, placementSettings: makePlacementSettings())
        controller.show()
        #expect(controller.handleKeyDown(try key("k", .command)))
        return controller
    }

    /// 链接：⌘K → ↓↓↓ 到「在浏览器中打开」→ ↩，面板菜单收起并把网址交给宿主。
    @Test func linkIsOpenedInTheBrowserFromTheMenu() throws {
        let model = makePanelModel(copying: ["https://github.com/openvetta/folita"])
        var opened: [URL] = []
        model.onOpenURL = { opened.append($0) }
        let controller = try openMenu(model: model)
        defer { controller.hide() }

        for _ in 0..<3 { #expect(controller.handleKeyDown(try key("\u{F701}"))) }
        #expect(model.highlightedActionsMenuEntry == .openInBrowser)
        #expect(controller.handleKeyDown(try key("\r")))

        #expect(opened == [URL(string: "https://github.com/openvetta/folita")!])
        #expect(model.isShowingActionsMenu == false)
    }

    /// 多个邮箱：「发送邮件」→ 展开二级菜单 → 选地址 → 打开 mailto；Esc/← 先收回二级菜单。
    @Test func severalEmailsOpenASubmenuToPickTheRecipient() throws {
        let model = makePanelModel(copying: ["alice@example.com and bob@example.org"])
        var opened: [URL] = []
        model.onOpenURL = { opened.append($0) }
        let controller = try openMenu(model: model)
        defer { controller.hide() }

        for _ in 0..<3 { #expect(controller.handleKeyDown(try key("\u{F701}"))) }
        #expect(controller.handleKeyDown(try key("\u{F703}")))
        #expect(model.highlightedActionsMenuEntry == .sendEmailTo("alice@example.com"))

        // Esc 只收回二级菜单，高亮回到父条目，主菜单仍开着。
        #expect(controller.handleKeyDown(try key("\u{1B}")))
        #expect(model.actionsMenuExpanded == nil)
        #expect(model.isShowingActionsMenu)
        #expect(model.highlightedActionsMenuEntry == .sendEmail(addresses: ["alice@example.com", "bob@example.org"]))

        // ↩ 再次展开，高亮仍在父条目上；↓↓ 越过第一个地址选到第二个。
        #expect(controller.handleKeyDown(try key("\r")))
        #expect(model.highlightedActionsMenuEntry == .sendEmail(addresses: ["alice@example.com", "bob@example.org"]))
        for _ in 0..<2 { #expect(controller.handleKeyDown(try key("\u{F701}"))) }
        #expect(model.highlightedActionsMenuEntry == .sendEmailTo("bob@example.org"))
        #expect(controller.handleKeyDown(try key("\r")))

        #expect(opened == [URL(string: "mailto:bob@example.org")!])
        #expect(model.isShowingActionsMenu == false)
    }

    @Test func singleEmailIsSentDirectly() throws {
        let model = makePanelModel(copying: ["alice@example.com"])
        var opened: [URL] = []
        model.onOpenURL = { opened.append($0) }
        let controller = try openMenu(model: model)
        defer { controller.hide() }

        for _ in 0..<3 { #expect(controller.handleKeyDown(try key("\u{F701}"))) }
        #expect(controller.handleKeyDown(try key("\r")))
        #expect(opened == [URL(string: "mailto:alice@example.com")!])
    }

    /// 颜色：⌘K → 「转换颜色格式」展开成右侧二级菜单（直接写出色值）→ 选 RGB → 复制并提示已复制，面板保持打开。
    @Test func colorIsConvertedAndCopiedFromTheMenu() async throws {
        let model = makePanelModel(copying: ["#1E90FF"])
        var copied: [String] = []
        model.onCopyText = { copied.append($0) }
        model.copyFeedbackDuration = .zero
        let controller = try openMenu(model: model)
        defer { controller.hide() }

        for _ in 0..<3 { #expect(controller.handleKeyDown(try key("\u{F701}"))) }
        let convert = ClipboardActionsMenuEntry.convertColor(Self.blue, excluding: .hex)
        #expect(model.highlightedActionsMenuEntry == convert)
        let menuBefore = try #require(model.actionsMenuFrame)
        #expect(controller.handleKeyDown(try key("\r")))
        #expect(model.isShowingActionsMenu)
        #expect(model.actionsMenuExpanded == convert)
        // 二级菜单是旁边的另一张卡片：一级卡片大小位置不变，两张卡片不重叠。
        let submenu = try #require(model.actionsSubmenuFrame)
        #expect(model.actionsMenuFrame == menuBefore)
        #expect(!submenu.intersects(menuBefore))
        #expect(model.actionsMenuTopRows.count == 6)
        #expect(model.actionsMenuChildRows.map(\.entry) == [
            .convertTo(.rgb, text: "rgb(30, 144, 255)"), .convertTo(.hsl, text: "hsl(210, 100%, 56%)"),
        ])
        // 点二级卡片同样交给按钮，不当作点在菜单外。
        #expect(controller.handleMouseDown(at: CGPoint(x: submenu.midX, y: submenu.midY), isRightClick: false) == false)
        #expect(model.isShowingActionsMenu)

        #expect(controller.handleKeyDown(try key("\u{F701}")))
        #expect(model.highlightedActionsMenuEntry == .convertTo(.rgb, text: "rgb(30, 144, 255)"))
        #expect(controller.handleKeyDown(try key("\r")))

        #expect(copied == ["rgb(30, 144, 255)"])
        #expect(model.isShowingActionsMenu == false)
        #expect(controller.isVisible)
        #expect(model.copyFeedback == "rgb(30, 144, 255)")

        // 提示稍后自行消失。
        await model.copyFeedbackTask?.value
        #expect(model.copyFeedback == nil)
    }

    /// 详情区的按钮走同一组模型动作；与内容不符的条目不触发。
    @Test func peekActionsOnlyApplyToMatchingItems() throws {
        let model = makePanelModel(copying: ["#1E90FF", "https://folita.app", "plain"])
        var opened: [URL] = []
        var copied: [String] = []
        model.onOpenURL = { opened.append($0) }
        model.onCopyText = { copied.append($0) }
        func item(_ category: ClipCategory) throws -> HistoryItem {
            try #require(model.visibleItems.first { $0.category == category })
        }

        model.openInBrowser(try item(.text))
        model.convertColor(of: try item(.link), to: .rgb)
        #expect(opened.isEmpty && copied.isEmpty && model.copyFeedback == nil)

        model.openInBrowser(try item(.link))
        model.composeEmail(to: "a@x.com")
        model.convertColor(of: try item(.color), to: .hsl)
        #expect(opened == [URL(string: "https://folita.app")!, URL(string: "mailto:a@x.com")!])
        #expect(copied == ["hsl(210, 100%, 56%)"])
        #expect(model.copyFeedback == "hsl(210, 100%, 56%)")
    }

    // MARK: 详情布局

    @Test(arguments: appearances)
    func peekLaysOutForBrandedLinksEmailsAndColors(locale: String, scheme: ColorScheme) throws {
        let model = makePanelModel(copying: [
            "https://github.com/openvetta/folita", "https://x.com/jack/status/20", "https://www.youtube.com/watch?v=abc123",
            "https://example.com", "alice@example.com", "alice@example.com bob@example.org", "rgb(30 144 255)",
        ])
        let size = ClipboardPanelMetrics.peekDetailFrame(in: ClipboardPanelMetrics.containerSize(isPeeking: true)).size
        for item in model.visibleItems {
            let host = NSHostingView(
                rootView: ClipPeekPanel(item: item)
                    .frame(width: size.width, height: size.height)
                    .environment(\.locale, Locale(identifier: locale))
                    .environment(\.colorScheme, scheme)
            )
            host.layoutSubtreeIfNeeded()
            #expect(host.fittingSize == size)
        }
    }

    // MARK: 粘贴转换结果

    /// 转换结果以纯文本写回剪贴板，只复制不粘贴，并带上自己的标记避免被监听重复入库。
    @Test func copyingConvertedTextWritesPlainTextWithoutPasting() {
        let pasteboard = NSPasteboard(name: .init("FolitaTests.Convert.\(UUID().uuidString)"))
        let suite = "FolitaTests.Convert.\(UUID().uuidString)"
        var keystrokes: [PasteTarget] = []
        defer {
            pasteboard.releaseGlobally()
            UserDefaults().removePersistentDomain(forName: suite)
        }
        let service = PasteService(
            pasteboard: pasteboard,
            store: ClipboardHistoryStore(container: HistoryStorage.makeInMemoryContainer(), limit: { 500 }),
            settings: PasteSettings(userDefaults: UserDefaults(suiteName: suite)!),
            accessibility: AccessibilityAccess(isTrusted: { true }, requestAccess: {}),
            sendPasteKeystroke: { keystrokes.append($0) }
        )

        service.copy(text: "rgb(30, 144, 255)")
        #expect(pasteboard.string(forType: .string) == "rgb(30, 144, 255)")
        #expect(pasteboard.types?.contains(.folitaOrigin) == true)
        #expect(keystrokes.isEmpty)
    }

    // MARK: 详情

    /// 右上角有按钮的条目，文字预览要从按钮下方开始。
    @Test func actionButtonsReserveRoomAboveTextPreviews() {
        #expect(ClipPeekCard.hasActionButtons(details("plain text")) == false)
        #expect(ClipPeekCard.hasActionButtons(details("mail me: a@x.com")))
        #expect(ClipPeekCard.hasActionButtons(details("https://folita.app")))
        #expect(ClipPeekCard.hasActionButtons(details("#1E90FF")))
    }

    @Test func repositoryTitleSplitsOwnerAndName() {
        let target = LinkTarget(brand: .github, kind: .repository, title: "openvetta/folita")
        let title = LinkBrandCard.title(of: target)
        #expect(String(title.characters) == "openvetta/folita")
        #expect(title.runs.count == 2)
        #expect(LinkBrandCard.title(of: LinkTarget(brand: .x, kind: .profile, title: "@jack")).runs.count == 1)
    }

    @Test(arguments: appearances)
    func copyToastLaysOut(locale: String, scheme: ColorScheme) {
        let host = NSHostingView(
            rootView: CopyFeedbackToast(text: "hsla(210, 100%, 56%, 0.5)")
                .environment(\.locale, Locale(identifier: locale))
                .environment(\.colorScheme, scheme)
        )
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize.width > 0 && host.fittingSize.width <= ClipboardPanelMetrics.containerSize.width)
    }

    // MARK: 本地化

    @Test func newCopyIsLocalized() {
        let copy: [(LocalizedStringResource, String)] = [
            ("Open in Browser", "在浏览器中打开"), ("Copied to Clipboard", "已复制到剪贴板"), ("Send Email", "发送邮件"), ("Convert Color", "转换颜色格式"),
            (LinkTarget.Kind.repository.title, "仓库"), (LinkTarget.Kind.profile.title, "个人主页"),
            (LinkTarget.Kind.gist.title, "代码片段"), (LinkTarget.Kind.post.title, "帖子"),
            (LinkTarget.Kind.video.title, "视频"), (LinkTarget.Kind.channel.title, "频道"),
            (LinkTarget.Kind.page.title, "链接"),
        ]
        for (resource, chinese) in copy {
            var en = resource, zh = resource
            en.locale = Locale(identifier: "en")
            zh.locale = Locale(identifier: "zh-Hans")
            #expect(String(localized: zh) == chinese)
            #expect(String(localized: en) == resource.key)
        }
    }
}
