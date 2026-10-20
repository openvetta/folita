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
        #expect(localized("Clear Search", "zh-Hans") == "清除搜索")
        #expect(localized("Search", "zh-Hans") == "搜索")
        #expect(localized("Filter", "zh-Hans") == "筛选")
        #expect(localized("Search…", "en") == "Search…")
        #expect(localized("Search…", "zh-Hans") == "搜索…")
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

    @Test func languageOptionTitlesInEnglish() {
        let titles = AppLanguage.allCases.map { localized($0.title, "en") }
        #expect(titles == ["System Default", "English", "Simplified Chinese"])
    }

    @Test func languageOptionTitlesInSimplifiedChinese() {
        let titles = AppLanguage.allCases.map { localized($0.title, "zh-Hans") }
        #expect(titles == ["跟随系统", "英文", "简体中文"])
    }

    @Test func generalSettingsCopyIsLocalized() {
        #expect(localized("Language", "en") == "Language")
        #expect(localized("Language", "zh-Hans") == "语言")
        #expect(localized("Follow system language settings by default.", "en") == "Follow system language settings by default.")
        #expect(localized("Follow system language settings by default.", "zh-Hans") == "默认跟随系统语言设置。")
        #expect(localized("Choose your preferred display language for Folita.", "en") == "Choose your preferred display language for Folita.")
        #expect(localized("Choose your preferred display language for Folita.", "zh-Hans") == "选择 Folita 的显示语言。")
    }

    @Test func historyRecoveryAlertIsLocalized() {
        #expect(localized("Clipboard history could not be opened", "zh-Hans") == "无法打开剪贴历史")
        let path = "/tmp/History-corrupted"
        #expect(localized("Folita started a new history. The previous data was moved to \(path).", "en")
            == "Folita started a new history. The previous data was moved to /tmp/History-corrupted.")
        #expect(localized("Folita started a new history. The previous data was moved to \(path).", "zh-Hans")
            == "Folita 已新建历史记录，原有数据已移至 /tmp/History-corrupted。")
    }
}
