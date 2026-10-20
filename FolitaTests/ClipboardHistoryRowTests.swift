import AppKit
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct ClipboardHistoryRowTests {
    nonisolated private static let appearances: [(String, ColorScheme)] = [
        ("zh-Hans", .light), ("zh-Hans", .dark), ("en", .light), ("en", .dark),
    ]

    private static let samples: [[ClipContent]] = [
        [ClipContent(type: .string, data: Data("第一行\n第二行\n第三行".utf8))],
        [ClipContent(type: .string, data: Data("#1E90FF".utf8))],
        [ClipContent(type: .string, data: Data("https://folita.app".utf8))],
        [
            ClipContent(type: .fileURL, data: URL(filePath: "/tmp/a.txt").dataRepresentation),
            ClipContent(type: .fileURL, data: URL(filePath: "/tmp/b.txt").dataRepresentation),
        ],
        [ClipContent(type: .png, data: Data([0, 1, 2]))],
    ]

    /// 存储释放会重置 SwiftData 上下文并让历史对象失效，因此测试期间必须持有到用例结束。
    @MainActor
    private final class StoreKeeper {
        var stores: [ClipboardHistoryStore] = []
    }

    private let keeper = StoreKeeper()

    private func item(_ contents: [ClipContent]) -> HistoryItem {
        let store = ClipboardHistoryStore(container: HistoryStorage.makeInMemoryContainer(), limit: { 500 })
        keeper.stores.append(store)
        store.record(CapturedClip(contents: contents, sourceBundleID: "com.apple.finder"))
        return store.items[0]
    }

    private func height(of row: ClipboardHistoryRow, locale: String, scheme: ColorScheme) -> CGFloat {
        let host = NSHostingView(rootView: row
            .frame(width: 392)
            .environment(\.locale, Locale(identifier: locale))
            .environment(\.colorScheme, scheme))
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize.width == 392)
        return host.fittingSize.height
    }

    /// 选中行就地展开显示详情，其余行保持单行。
    @Test(arguments: appearances)
    func selectedRowExpandsWithDetails(locale: String, scheme: ColorScheme) {
        for contents in Self.samples {
            let item = item(contents)
            let collapsed = height(of: ClipboardHistoryRow(item: item, isSelected: false), locale: locale, scheme: scheme)
            for canAutoPaste in [true, false] {
                let expanded = height(
                    of: ClipboardHistoryRow(item: item, isSelected: true, targetAppName: "Notes", canAutoPaste: canAutoPaste),
                    locale: locale,
                    scheme: scheme
                )
                #expect(expanded > collapsed)
            }
        }
    }

    @Test func expandedCopyIsLocalized() {
        func zh(_ resource: LocalizedStringResource) -> String {
            var resource = resource
            resource.locale = Locale(identifier: "zh-Hans")
            return String(localized: resource)
        }
        let app = "Notes", count = 3
        #expect(zh("Paste to \(app)") == "粘贴到 Notes")
        #expect(zh("Copy") == "复制")
        #expect(zh("Plain Text") == "纯文本")
        #expect(zh("\(count) files") == "3 个文件")
        #expect(zh("\(count) characters") == "3 个字符")
        #expect(zh("and \(count) more") == "等另外 3 个")
        #expect(ClipCategory.allCases.map { zh($0.title) } == ["文本", "富文本", "图片", "文件", "链接", "颜色", "邮箱"])
    }

    @Test func presentationCapturesTargetAppAndPasteAbility() {
        let model = makePanelModel(copying: ["a"])
        model.targetAppProvider = { "Notes" }
        model.autoPasteProvider = { true }
        model.prepareForPresentation()
        #expect(model.targetAppName == "Notes")
        #expect(model.canAutoPaste)

        model.targetAppProvider = { nil }
        model.autoPasteProvider = { false }
        model.prepareForPresentation()
        #expect(model.targetAppName == nil)
        #expect(!model.canAutoPaste)
    }
}
