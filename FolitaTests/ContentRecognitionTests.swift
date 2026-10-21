import Foundation
import Testing
@testable import Folita

/// 颜色、邮箱、站点链接的识别与转换规则（纯逻辑，不涉及界面）。
@MainActor
struct ContentRecognitionTests {
    private func details(_ text: String) -> ClipDetails {
        let contents = [ClipContent(type: .string, data: Data(text.utf8))]
        return ClipDetails(contents: contents, category: ClipClassification.category(of: contents))
    }

    // MARK: 颜色

    @Test func colorSyntaxesAreRecognizedAndConvertible() throws {
        let samples = [
            "#1E90FF", "#1e90ff", "#1E9", "rgb(30, 144, 255)", "rgb(30 144 255)",
            "hsl(210, 100%, 56%)", "hsl(210deg 100% 56%)", "rgba(30, 144, 255, 0.5)", "rgb(30 144 255 / 50%)",
        ]
        for sample in samples {
            #expect(ClipClassification.derivedCategory(ofText: sample) == .color, "\(sample)")
            #expect(details(sample).color != nil, "\(sample)")
        }
        #expect(ClipClassification.derivedCategory(ofText: "rgb(1, 2)") == .text)
        #expect(ClipClassification.derivedCategory(ofText: "#12") == .text)

        let blue = try #require(RGBAColor(parsing: "#1E90FF"))
        #expect(ColorFormat.hex.string(for: blue) == "#1E90FF")
        #expect(ColorFormat.rgb.string(for: blue) == "rgb(30, 144, 255)")
        #expect(ColorFormat.hsl.string(for: blue) == "hsl(210, 100%, 56%)")

        let translucent = try #require(RGBAColor(parsing: "rgb(30 144 255 / 50%)"))
        #expect(ColorFormat.rgb.string(for: translucent) == "rgba(30, 144, 255, 0.5)")
        #expect(ColorFormat.hex.string(for: translucent) == "#1E90FF80")
        #expect(ColorFormat.hsl.string(for: translucent) == "hsla(210, 100%, 56%, 0.5)")
    }

    /// 转换结果还能被识别回同一种颜色。
    @Test(arguments: ColorFormat.allCases)
    func convertedTextRoundTrips(format: ColorFormat) throws {
        let original = try #require(RGBAColor(parsing: "#1E90FF"))
        let text = format.string(for: original)
        #expect(ColorFormat.detect(text) == format)
        let parsed = try #require(RGBAColor(parsing: text))
        #expect(abs(parsed.red - original.red) < 0.01)
        #expect(abs(parsed.green - original.green) < 0.01)
        #expect(abs(parsed.blue - original.blue) < 0.01)
    }

    // MARK: 邮箱与链接

    @Test func emailsAreCollectedInOrderWithoutDuplicates() {
        let found = details("Contact a@x.com, B@y.org and A@X.com").emails
        #expect(found == ["a@x.com", "B@y.org"])
        #expect(EmailAddresses.mailtoURL(to: "a@x.com")?.absoluteString == "mailto:a@x.com")
        // 网址里的 @ 不是收件人。
        #expect(details("https://user@example.com/path").emails.isEmpty)
        #expect(details("no address here").emails.isEmpty)
    }

    @Test func wellKnownLinksAreRecognized() throws {
        func target(_ text: String) -> LinkTarget? { LinkTarget(url: URL(string: text)!) }
        #expect(target("https://github.com/openvetta/folita") == LinkTarget(brand: .github, kind: .repository, title: "openvetta/folita"))
        #expect(target("https://github.com/openvetta")?.kind == .profile)
        #expect(target("https://github.com/settings/profile")?.kind == .page)
        #expect(target("https://x.com/jack/status/20") == LinkTarget(brand: .x, kind: .post, title: "@jack"))
        #expect(target("https://twitter.com/jack")?.kind == .profile)
        #expect(target("https://www.youtube.com/watch?v=abc123") == LinkTarget(brand: .youtube, kind: .video, title: "abc123"))
        #expect(target("https://youtu.be/abc123")?.title == "abc123")
        #expect(target("https://www.youtube.com/@folita")?.kind == .channel)
        #expect(target("https://example.com/openvetta/folita") == nil)
        #expect(details("https://github.com/openvetta/folita").linkTarget?.brand == .github)
    }
}
