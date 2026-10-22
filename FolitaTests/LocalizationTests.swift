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
        #expect(titles == ["General", "Favorites", "Shortcuts", "History", "Privacy", "About"])
    }

    @Test func sectionTitlesInSimplifiedChinese() {
        let titles = MainSection.allCases.map { localized($0.title, "zh-Hans") }
        #expect(titles == ["通用", "收藏夹", "快捷键", "历史记录", "隐私", "关于"])
    }

    @Test func clipboardPanelCopyIsLocalized() {
        #expect(localized("Clear Search", "zh-Hans") == "清除搜索")
        #expect(localized("Search", "zh-Hans") == "搜索")
        #expect(localized("Filter", "zh-Hans") == "筛选")
        #expect(localized("Search…", "en") == "Search…")
        #expect(localized("Search…", "zh-Hans") == "搜索…")
    }

    @Test func peekCopyIsLocalized() {
        let copy: [(LocalizedStringResource, String, String)] = [
            ("Preview", "Preview", "预览"),
            ("Information", "Information", "信息"),
            ("Source", "Source", "来源"),
            ("Type", "Type", "类型"),
            ("Dimensions", "Dimensions", "尺寸"),
            ("Characters", "Characters", "字符数"),
            ("Files", "Files", "文件数"),
            ("Size", "Size", "大小"),
            ("Copied", "Copied", "复制时间"),
            ("Preview the selected item", "Preview the selected item", "查看选中项详情"),
            ("Nothing to preview", "Nothing to preview", "没有可预览的内容"),
            ("Close the preview", "Close the preview", "关闭预览"),
            ("Open in Finder", "Open in Finder", "从访达打开"),
        ]
        for (resource, en, zh) in copy {
            #expect(localized(resource, "en") == en)
            #expect(localized(resource, "zh-Hans") == zh)
        }
    }

    @Test func actionsMenuCopyIsLocalized() {
        let copy: [(LocalizedStringResource, String, String)] = [
            ("More Actions", "More Actions", "更多操作"),
            ("Paste to %@", "Paste to %@", "粘贴到 %@"),
            ("Paste and Keep Window Open", "Paste and Keep Window Open", "粘贴并保持窗口打开"),
            ("Delete Entry", "Delete Entry", "删除此条"),
            ("Delete All Entries", "Delete All Entries", "删除全部"),
            ("Open the Main Panel", "Open the Main Panel", "打开主面板"),
        ]
        for (resource, en, zh) in copy {
            #expect(localized(resource, "en") == en)
            #expect(localized(resource, "zh-Hans") == zh)
        }
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

    @Test func appIconCopyIsLocalized() {
        #expect(AppIconOption.allCases.map { localized($0.title, "en") } == [
            "Fox", "Dog", "Chick", "Black Cat", "Panda", "Rabbit",
            "Frog", "Pig", "Bear", "Penguin", "Koala", "Snake",
        ])
        #expect(AppIconOption.allCases.map { localized($0.title, "zh-Hans") } == [
            "狐狸", "小狗", "小鸡", "小黑猫", "熊猫", "兔子",
            "青蛙", "小猪", "小熊", "企鹅", "考拉", "小蛇",
        ])
        #expect(localized("App Icon", "en") == "App Icon")
        #expect(localized("App Icon", "zh-Hans") == "应用图标")
        let footer: LocalizedStringResource = "The menu bar shows the selected icon while Folita is running. Finder and other places keep the default fox."
        #expect(localized(footer, "en") == "The menu bar shows the selected icon while Folita is running. Finder and other places keep the default fox.")
        #expect(localized(footer, "zh-Hans") == "Folita 运行期间，菜单栏显示所选图标；访达等其他位置仍显示默认的狐狸图标。")
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
        #expect(localized("Not Now", "zh-Hans") == "以后再说")
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

    @Test func panelPlacementCopyIsLocalized() {
        let expected: [(LocalizedStringResource, String)] = [
            ("Panel Position", "面板位置"),
            ("Position", "位置"),
            (PanelPlacement.topCenter.title, "屏幕顶部居中"),
            (PanelPlacement.center.title, "屏幕正中心"),
            (PanelPlacement.cursor.title, "光标位置"),
            ("Choose where the clipboard panel appears on the screen your mouse is on. Changes apply the next time you open it.",
             "选择剪贴面板在鼠标所在屏幕上的出现位置，下次呼出时生效。"),
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

    @Test func updatesCopyIsLocalized() {
        #expect(localized("Check for updates automatically", "zh-Hans") == "自动检查更新")
        #expect(localized("Check for Updates…", "zh-Hans") == "检查更新…")
        #expect(localized("Updates are not configured for this build.", "zh-Hans") == "此版本未配置自动更新。")
    }

    /// 收藏夹相关的固定文案都要有中英两版。
    @Test func favoritesCopyIsLocalized() {
        let copy: [(LocalizedStringResource, String, String)] = [
            ("Favorites", "Favorites", "收藏夹"),
            ("All", "All", "全部"),
            ("Work", "Work", "工作"),
            ("Life", "Life", "生活"),
            ("New Group", "New Group", "新建分组"),
            ("Group Name", "Group Name", "分组名称"),
            ("Group", "Group", "分组"),
            ("Remove from Favorites", "Remove from Favorites", "取消收藏"),
            ("Favorite", "Favorite", "收藏"),
            ("Delete Group", "Delete Group", "删除分组"),
            ("Rename", "Rename", "重命名"),
            ("Open or close Favorites", "Open or close Favorites", "打开或关闭收藏夹"),
            ("Go back, or close the panel", "Go back, or close the panel", "返回上一层或关闭面板"),
        ]
        for (resource, en, zh) in copy {
            #expect(localized(resource, "en") == en)
            #expect(localized(resource, "zh-Hans") == zh)
        }
    }

    /// 预设分组按界面语言播种：中文下写入的是「工作」「生活」。
    @MainActor
    @Test func defaultTabNamesFollowTheGivenLocale() {
        #expect(ClipboardHistoryStore.defaultTabNames(locale: Locale(identifier: "en")) == ["Work", "Life"])
        #expect(ClipboardHistoryStore.defaultTabNames(locale: Locale(identifier: "zh-Hans")) == ["工作", "生活"])
    }

    @Test func favoritesEmptyStateCopyIsLocalized() {
        let group: LocalizedStringResource = "Favorite items appear here. Press ⌘F on an item and pick a group."
        #expect(localized(group, "en") == "Favorite items appear here. Press ⌘F on an item and pick a group.")
        #expect(localized(group, "zh-Hans") == "收藏的内容会出现在这里。在条目上按 ⌘F，选一个分组即可收藏。")

        let tab: LocalizedStringResource = "Favorite items appear here. Press ⌘F on an item and pick this group."
        #expect(localized(tab, "en") == "Favorite items appear here. Press ⌘F on an item and pick this group.")
        #expect(localized(tab, "zh-Hans") == "收藏的内容会出现在这里。在条目上按 ⌘F，选这个分组即可收藏。")
    }

    /// 就地新建 / 编辑片段的入口与编辑器文案，中英两版都要有。
    @Test func addFavoriteTextCopyIsLocalized() {
        let copy: [(LocalizedStringResource, String, String)] = [
            ("Add Snippet", "Add Snippet", "添加片段"),
            ("New Snippet", "New Snippet", "新片段"),
            ("Edit", "Edit", "编辑"),
            ("Done", "Done", "完成"),
            ("Snippet", "Snippet", "片段"),
            ("Editing", "Editing", "正在编辑"),
            ("Type or paste text here…", "Type or paste text here…", "在此输入或粘贴文本…"),
            ("No snippets yet", "No snippets yet", "还没有片段"),
            ("Create a group first", "Create a group first", "请先新建分组"),
            ("Make a group with the + button, then add snippets here.", "Make a group with the + button, then add snippets here.", "用 + 按钮新建一个分组，然后在这里添加片段。"),
            ("Add a snippet to save text you want to keep close.", "Add a snippet to save text you want to keep close.", "添加一个片段，把想随手取用的文本存起来。"),
            ("Select a snippet, or add a new one.", "Select a snippet, or add a new one.", "选择一个片段，或添加一个新的。"),
            ("Copy to Clipboard", "Copy to Clipboard", "复制到剪贴板"),
        ]
        for (resource, en, zh) in copy {
            #expect(localized(resource, "en") == en)
            #expect(localized(resource, "zh-Hans") == zh)
        }
    }
}
