import Foundation

/// 主面板侧边栏的分区。新增设置页时在这里登记，标题需同步到 Localizable.xcstrings。
enum MainSection: String, CaseIterable, Identifiable, Hashable {
    case general
    case shortcuts
    case history
    case privacy
    case about

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .general: "General"
        case .shortcuts: "Shortcuts"
        case .history: "History"
        case .privacy: "Privacy"
        case .about: "About"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .shortcuts: "command"
        case .history: "clock.arrow.circlepath"
        case .privacy: "hand.raised"
        case .about: "info.circle"
        }
    }
}
