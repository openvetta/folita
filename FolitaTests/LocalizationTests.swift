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

    @Test func historyListCopyIsLocalized() {
        let expected: [(LocalizedStringResource, String)] = [
            ("No matches", "没有匹配项"),
            ("Try a different search or filter.", "换个关键词或筛选条件试试。"),
            ("Paste", "粘贴"),
            ("Paste as Plain Text", "以纯文本粘贴"),
            ("Delete", "删除"),
            ("Image", "图片"),
        ]
        for (key, chinese) in expected {
            #expect(localized(key, "zh-Hans") == chinese)
            #expect(localized(key, "en") == key.key)
        }
    }

    @Test func panelNoticeCopyIsLocalized() {
        #expect(localized("Auto-paste needs permission", "zh-Hans") == "自动粘贴需要授权")
        #expect(localized("Clipboard access is denied", "zh-Hans") == "剪贴板访问被拒绝")
        #expect(localized("Selected items are copied — press ⌘V to paste. Click to grant permission in System Settings.", "zh-Hans")
            == "选中的内容会先复制，按 ⌘V 即可粘贴。点击前往系统设置授权。")
        #expect(localized("Folita can't record new copies. Click to allow clipboard access in System Settings.", "zh-Hans")
            == "Folita 无法记录新的复制内容。点击前往系统设置允许访问剪贴板。")
    }

    @Test func generalStartupAndPasteCopyIsLocalized() {
        let expected: [(LocalizedStringResource, String)] = [
            ("Launch at login", "登录时启动"),
            ("Startup", "启动"),
            ("Paste automatically", "自动粘贴"),
            ("Granted", "已授权"),
            ("Open System Settings", "打开系统设置"),
            ("Permission", "权限"),
        ]
        for (key, chinese) in expected {
            #expect(localized(key, "zh-Hans") == chinese)
            #expect(localized(key, "en") == key.key)
        }
    }

    @Test func shortcutsCopyIsLocalized() {
        #expect(localized("Global", "zh-Hans") == "全局")
        #expect(localized("In the Clipboard Panel", "zh-Hans") == "剪贴面板内")
        for hint in PanelKeyHint.all {
            #expect(localized(hint.action, "en") == hint.action.key)
            #expect(localized(hint.action, "zh-Hans") != hint.action.key)
        }
    }

    @Test func historySettingsCopyIsLocalized() {
        let limit = 500
        #expect(localized("\(limit) items", "en") == "500 items")
        #expect(localized("\(limit) items", "zh-Hans") == "500 条")
        #expect(localized("Clear all clipboard history?", "zh-Hans") == "要清空全部剪贴历史吗？")
        #expect(localized("Storage Used", "zh-Hans") == "占用空间")
    }

    @Test func privacyCopyIsLocalized() {
        let expected: [(LocalizedStringResource, String)] = [
            ("Pause Recording", "暂停记录"),
            ("Ignored Apps", "忽略的应用"),
            ("Add App…", "添加应用…"),
            ("Content that password managers mark as hidden or temporary is never recorded.", "密码管理器标记为隐藏或临时的内容始终不会被记录。"),
        ]
        for (key, chinese) in expected {
            #expect(localized(key, "zh-Hans") == chinese)
            #expect(localized(key, "en") == key.key)
        }
    }

    @Test func aboutCopyIsLocalized() {
        let version = "0.1.0", build = "1"
        #expect(localized("Version \(version) (\(build))", "en") == "Version 0.1.0 (1)")
        #expect(localized("Version \(version) (\(build))", "zh-Hans") == "版本 0.1.0（1）")
        #expect(localized("Source Code", "zh-Hans") == "源代码")
    }
}
