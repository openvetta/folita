import AppKit
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct ClipPeekViewTests {
    nonisolated private static let appearances: [(String, ColorScheme)] = [
        ("zh-Hans", .light), ("zh-Hans", .dark), ("en", .light), ("en", .dark),
    ]

    private static func png(width: Int, height: Int) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )!
        return rep.representation(using: .png, properties: [:])!
    }

    /// 文本、链接、颜色、图片、多文件各一条，最后一条排在最前。
    private func makeSampleModel() -> ClipboardPanelModel {
        let model = makePanelModel(copying: [
            "A long paragraph\nwith several lines of text to preview",
            "https://folita.app/docs",
            "#1E90FF",
        ])
        model.store.record(CapturedClip(
            contents: [ClipContent(type: .png, data: Self.png(width: 64, height: 32))],
            sourceBundleID: "com.apple.finder"
        ))
        let urls = [URL(filePath: "/tmp/report.pdf"), URL(filePath: "/tmp/notes.txt")]
        model.store.record(CapturedClip(
            contents: urls.map { ClipContent(type: .fileURL, data: $0.dataRepresentation) },
            sourceBundleID: nil
        ))
        return model
    }

    private func item(_ model: ClipboardPanelModel, _ category: ClipCategory) throws -> HistoryItem {
        try #require(model.visibleItems.first { $0.category == category })
    }

    // MARK: 布局

    /// 预览时容器加宽到 1.5 倍；分割线在 1/3 处，列表在左、详情在右，详情右边与顶栏对齐、不压到底部把手。
    @Test func peekSplitsTheWiderContainerOneToTwo() {
        let normal = ClipboardPanelMetrics.containerSize
        let wide = ClipboardPanelMetrics.containerSize(isPeeking: true)
        #expect(wide.width == normal.width * 1.5)
        #expect(wide.height == normal.height)

        let inset = ClipboardPanelMetrics.contentInset
        let listRight = inset + ClipboardPanelMetrics.listColumnWidth(isPeeking: true)
        let detail = ClipboardPanelMetrics.peekDetailFrame(in: wide)
        let divider = ClipboardPanelMetrics.peekDividerX(in: wide)
        #expect(abs(divider - wide.width / 3) <= 0.5)
        #expect(listRight < divider && divider < detail.minX)
        #expect(divider - listRight == detail.minX - divider)
        #expect(detail.maxX == wide.width - inset)
        #expect(detail.minY > ClipboardPanelMetrics.contentTopInset + ClipboardPanelMetrics.controlHeight)
        #expect(detail.maxY <= wide.height - 20)

        #expect(ClipboardPanelMetrics.listColumnWidth(isPeeking: false) == normal.width - inset * 2)
    }

    @Test(arguments: appearances)
    func everyCategoryLaysOut(locale: String, scheme: ColorScheme) throws {
        let model = makeSampleModel()
        let size = ClipboardPanelMetrics.peekDetailFrame(in: ClipboardPanelMetrics.containerSize(isPeeking: true)).size

        for category in [ClipCategory.text, .link, .color, .image, .file] {
            let panel = ClipPeekPanel(item: try item(model, category))
                .frame(width: size.width, height: size.height)
                .environment(\.locale, Locale(identifier: locale))
                .environment(\.colorScheme, scheme)
            let host = NSHostingView(rootView: panel)
            host.layoutSubtreeIfNeeded()
            #expect(host.fittingSize == size)
        }
    }

    /// 搜索后列表为空时，详情区显示空状态而不是退出预览。
    @Test(arguments: appearances)
    func emptyDetailLaysOut(locale: String, scheme: ColorScheme) {
        let size = ClipboardPanelMetrics.peekDetailFrame(in: ClipboardPanelMetrics.containerSize(isPeeking: true)).size
        let panel = ClipPeekPanel(item: nil)
            .frame(width: size.width, height: size.height)
            .environment(\.locale, Locale(identifier: locale))
            .environment(\.colorScheme, scheme)
        let host = NSHostingView(rootView: panel)
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize == size)
    }

    /// 文件条目的「从访达打开」把条目里的全部文件交给宿主；非文件条目不触发。
    @Test func openInFinderPassesAllFilesOfTheItem() throws {
        let model = makeSampleModel()
        var revealed: [[URL]] = []
        model.onRevealInFinder = { revealed.append($0) }

        model.openInFinder(try item(model, .text))
        #expect(revealed.isEmpty)

        model.openInFinder(try item(model, .file))
        #expect(revealed == [[URL(filePath: "/tmp/report.pdf"), URL(filePath: "/tmp/notes.txt")]])
    }

    // MARK: 图片文件

    private func writeTemporaryPNG(width: Int, height: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "FolitaTests-\(UUID().uuidString).png")
        try Self.png(width: width, height: height).write(to: url)
        return url
    }

    private func fileItem(in model: ClipboardPanelModel, _ urls: [URL]) throws -> HistoryItem {
        model.store.record(CapturedClip(
            contents: urls.map { ClipContent(type: .fileURL, data: $0.dataRepresentation) },
            sourceBundleID: nil
        ))
        return try #require(model.visibleItems.first)
    }

    /// 复制单个图片文件时列表缩略图与详情大图都取自文件；多个文件、非图片文件、文件已删除时回退为文件图标。
    @Test func imageFileProvidesThumbnailsOnlyForSingleReadableImage() async throws {
        let model = makePanelModel()
        let png = try writeTemporaryPNG(width: 64, height: 32)
        let text = FileManager.default.temporaryDirectory.appending(path: "FolitaTests-\(UUID().uuidString).txt")
        try Data("hi".utf8).write(to: text)
        defer { try? FileManager.default.removeItem(at: png); try? FileManager.default.removeItem(at: text) }

        let single = try fileItem(in: model, [png])
        #expect(ClipDetails(contents: single.clipContents, category: single.category).imageFileURL == png)
        let thumbnail = await ClipPreviewImages.thumbnail(for: single, maxPixelSize: 64)
        #expect(thumbnail?.width == 64)

        let plain = try fileItem(in: model, [text])
        #expect(ClipDetails(contents: plain.clipContents, category: plain.category).imageFileURL == nil)
        #expect(await ClipPreviewImages.thumbnail(for: plain, maxPixelSize: 64) == nil)

        let several = try fileItem(in: model, [png, text])
        #expect(ClipDetails(contents: several.clipContents, category: several.category).imageFileURL == nil)
        #expect(await ClipPreviewImages.thumbnail(for: several, maxPixelSize: 64) == nil)

        try FileManager.default.removeItem(at: png)
        #expect(await ClipPreviewImages.thumbnail(for: single, maxPixelSize: 64) == nil)
    }

    @Test(arguments: appearances)
    func imageFileDetailLaysOut(locale: String, scheme: ColorScheme) throws {
        let model = makePanelModel()
        let png = try writeTemporaryPNG(width: 64, height: 32)
        defer { try? FileManager.default.removeItem(at: png) }
        let item = try fileItem(in: model, [png])
        let size = ClipboardPanelMetrics.peekDetailFrame(in: ClipboardPanelMetrics.containerSize(isPeeking: true)).size

        let host = NSHostingView(rootView: ClipPeekPanel(item: item)
            .frame(width: size.width, height: size.height)
            .environment(\.locale, Locale(identifier: locale))
            .environment(\.colorScheme, scheme))
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize == size)
    }

    // MARK: 信息区

    @Test func imageInformationShowsSourceAndDimensions() throws {
        // 模型要在整个测试期间持有：它释放后内存库随之销毁，再读条目内容会触发 SwiftData 断言。
        let model = makeSampleModel()
        let image = try item(model, .image)
        let details = ClipDetails(contents: image.clipContents, category: image.category)

        #expect(ClipPeekField.fields(for: image, details: details) == [
            .source(bundleID: "com.apple.finder"),
            .type(.image),
            .dimensions(CGSize(width: 64, height: 32)),
            .size(details.byteCount),
            .copied(image.lastCopiedAt),
        ])
    }

    @Test func textAndFileInformationShowCounts() throws {
        let model = makeSampleModel()

        let text = try item(model, .text)
        let textDetails = ClipDetails(contents: text.clipContents, category: text.category)
        #expect(ClipPeekField.fields(for: text, details: textDetails) == [
            .type(.text),
            .characters(textDetails.characterCount ?? -1),
            .size(textDetails.byteCount),
            .copied(text.lastCopiedAt),
        ])

        let files = try item(model, .file)
        let fileDetails = ClipDetails(contents: files.clipContents, category: files.category)
        #expect(ClipPeekField.fields(for: files, details: fileDetails).contains(.files(2)))
        #expect(!ClipPeekField.fields(for: files, details: fileDetails).contains { if case .characters = $0 { true } else { false } })
    }

    @Test func longTextIsTrimmedForPreview() {
        #expect(ClipPeekCard.previewText("  hello \n") == "hello")
        let long = String(repeating: "a", count: 12)
        #expect(ClipPeekCard.previewText(long, limit: 10) == String(repeating: "a", count: 10) + "…")
        #expect(ClipPeekCard.previewText(long, limit: 12) == long)
    }
}
