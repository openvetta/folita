import AppKit
import Testing
@testable import Folita

struct ClipDetailsTests {
    private func text(_ string: String) -> ClipContent {
        ClipContent(type: .string, data: Data(string.utf8))
    }

    private func png(width: Int, height: Int) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )!
        return rep.representation(using: .png, properties: [:])!
    }

    @Test func textCountsCharactersLinesAndBytes() {
        let details = ClipDetails(contents: [text("你好\nworld\n")], category: .text)
        #expect(details.characterCount == 9)
        #expect(details.lineCount == 3)
        #expect(details.byteCount == 13)
        #expect(details.pixelSize == nil)
    }

    @Test func imageReadsPixelSizeFromHeader() {
        let details = ClipDetails(contents: [ClipContent(type: .png, data: png(width: 842, height: 790))], category: .image)
        #expect(details.pixelSize == CGSize(width: 842, height: 790))
        #expect(details.text == nil)
    }

    @Test func filesListEveryURL() {
        let urls = [URL(filePath: "/tmp/a.txt"), URL(filePath: "/tmp/b.png")]
        let details = ClipDetails(
            contents: urls.map { ClipContent(type: .fileURL, data: $0.dataRepresentation) },
            category: .file
        )
        #expect(details.fileURLs == urls)
    }

    @Test func linkAndColorAreParsed() {
        #expect(ClipDetails(contents: [text("https://folita.app/docs")], category: .link).link?.host() == "folita.app")
        #expect(ClipDetails(contents: [text("#FF0000")], category: .color).color == RGBAColor(red: 1, green: 0, blue: 0))
    }

    @Test func richTextOnlyFallsBackToExtractedText() throws {
        let attributed = NSAttributedString(string: "Bold")
        let rtf = try #require(attributed.rtf(from: NSRange(location: 0, length: 4)))
        #expect(ClipDetails(contents: [ClipContent(type: .rtf, data: rtf)], category: .richText).text == "Bold")
    }

    @Test(arguments: [
        ("#fff", RGBAColor(red: 1, green: 1, blue: 1)),
        ("#00000080", RGBAColor(red: 0, green: 0, blue: 0, alpha: 128.0 / 255)),
        ("#1E90FF", RGBAColor(red: 30.0 / 255, green: 144.0 / 255, blue: 1)),
        ("rgb(255, 0, 0)", RGBAColor(red: 1, green: 0, blue: 0)),
        ("rgba(0, 0, 255, 0.5)", RGBAColor(red: 0, green: 0, blue: 1, alpha: 0.5)),
        ("hsl(120, 100%, 50%)", RGBAColor(red: 0, green: 1, blue: 0)),
        ("hsl(0, 0%, 50%)", RGBAColor(red: 0.5, green: 0.5, blue: 0.5)),
    ])
    func parsesColorFormats(input: String, expected: RGBAColor) throws {
        let color = try #require(RGBAColor(parsing: input))
        #expect(abs(color.red - expected.red) < 0.001)
        #expect(abs(color.green - expected.green) < 0.001)
        #expect(abs(color.blue - expected.blue) < 0.001)
        #expect(abs(color.alpha - expected.alpha) < 0.001)
    }

    @Test(arguments: ["#12345", "rgb(1,2)", "blue", "#zzz"])
    func rejectsInvalidColors(input: String) {
        #expect(RGBAColor(parsing: input) == nil)
    }
}
