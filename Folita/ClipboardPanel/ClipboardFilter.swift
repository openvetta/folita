import Foundation

/// 剪贴面板的筛选类型。仅描述界面可选项，真正的过滤在接入剪贴记录后生效。
enum ClipboardFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case text
    case images
    case files
    case links
    case colors
    case emails

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .all: "All Types"
        case .text: "Text Only"
        case .images: "Images Only"
        case .files: "Files Only"
        case .links: "Link Only"
        case .colors: "Colors Only"
        case .emails: "Emails Only"
        }
    }

    var symbolName: String {
        switch self {
        case .all: "list.bullet"
        case .text: "textformat"
        case .images: "photo"
        case .files: "doc"
        case .links: "link"
        case .colors: "paintpalette"
        case .emails: "at"
        }
    }
}
