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

    private func localized(_ resource: LocalizedStringResource, _ identifier: String) -> String {
        var resource = resource
        resource.locale = Locale(identifier: identifier)
        return String(localized: resource)
    }

    /// 内容与选中状态都不改变行高，列表滚动时不会跳动。
    @Test(arguments: appearances)
    func rowsShareOneHeight(locale: String, scheme: ColorScheme) {
        for contents in Self.samples {
            let item = item(contents)
            for isSelected in [false, true] {
                let height = height(
                    of: ClipboardHistoryRow(item: item, isSelected: isSelected),
                    locale: locale,
                    scheme: scheme
                )
                #expect(height == ClipboardPanelMetrics.historyRowHeight)
            }
        }
    }

    /// 图片的标题显示像素尺寸，中英文都要带上单位，且不出现千位分隔符。
    @Test func imageTitleShowsPixelSize() {
        let size = CGSize(width: 1024, height: 768)
        #expect(localized(ClipboardHistoryRow.imageTitle(pixelSize: size), "en") == "Image (1024 × 768 px)")
        #expect(localized(ClipboardHistoryRow.imageTitle(pixelSize: size), "zh-Hans") == "图片（1024 × 768 像素）")
        #expect(localized(ClipboardHistoryRow.imageTitle(pixelSize: nil), "zh-Hans") == "图片")
    }

    /// 文本取第一行，文件只保留文件名。
    @Test func titlesUseFirstLineAndFileNames() {
        #expect(ClipboardHistoryRow.title(of: item(Self.samples[0])) == "第一行")
        #expect(ClipboardHistoryRow.title(of: item(Self.samples[3])) == "a.txt, b.txt")
        #expect(ClipboardHistoryRow.title(of: item(Self.samples[2])) == "https://folita.app")
    }

    /// 有实心变体的类别用 `.fill`，并且每个符号都真实存在（避免拼写错误的名称静默消失）。
    @Test func typeSymbolsAreValidAndFilledWhereAvailable() {
        for category in ClipCategory.allCases {
            #expect(NSImage(systemSymbolName: category.symbolName, accessibilityDescription: nil) != nil)
        }
        for category in [ClipCategory.richText, .image, .file, .color] {
            #expect(category.symbolName.hasSuffix(".fill"))
        }
    }

    @Test func metadataCopyIsLocalized() {
        func zh(_ resource: LocalizedStringResource) -> String { localized(resource, "zh-Hans") }
        let count = 3
        #expect(zh("\(count) files") == "3 个文件")
        #expect(zh("\(count) characters") == "3 个字符")
        #expect(ClipCategory.allCases.map { zh($0.title) } == ["文本", "富文本", "图片", "文件", "链接", "颜色", "邮箱"])
    }
}
