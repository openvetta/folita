import Foundation
import Testing
@testable import Folita

struct LocalizationTests {
    private func localized(_ resource: LocalizedStringResource, _ identifier: String) -> String {
        var resource = resource
        resource.locale = Locale(identifier: identifier)
        return String(localized: resource)
    }

    @Test func sectionTitlesInEnglish() {
        let titles = MainSection.allCases.map { localized($0.title, "en") }
        #expect(titles == ["General", "Shortcuts", "History", "Privacy", "About"])
    }

    @Test func sectionTitlesInSimplifiedChinese() {
        let titles = MainSection.allCases.map { localized($0.title, "zh-Hans") }
        #expect(titles == ["通用", "快捷键", "历史记录", "隐私", "关于"])
    }

    @Test func clipboardPanelCopyIsLocalized() {
        #expect(localized("Clipboard", "en") == "Clipboard")
        #expect(localized("Clipboard", "zh-Hans") == "剪贴板")
        #expect(localized("Close", "zh-Hans") == "关闭")
        #expect(localized("Filter", "zh-Hans") == "筛选")
    }

    @Test func filterTitlesInEnglish() {
        let titles = ClipboardFilter.allCases.map { localized($0.title, "en") }
        #expect(titles == [
            "All Types", "Text Only", "Images Only", "Files Only",
            "Link Only", "Colors Only", "Emails Only",
        ])
    }

    @Test func filterTitlesInSimplifiedChinese() {
        let titles = ClipboardFilter.allCases.map { localized($0.title, "zh-Hans") }
        #expect(titles == [
            "全部类型", "仅文本", "仅图片", "仅文件",
            "仅链接", "仅颜色", "仅邮箱",
        ])
    }
}
