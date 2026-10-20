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
        #expect(localized("No clipboard history yet", "zh-Hans") == "还没有剪贴记录")
    }
}
