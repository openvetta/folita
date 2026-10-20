import Foundation
import Observation

@MainActor
@Observable
final class PasteSettings {
    static let autoPasteKey = "FolitaAutoPaste"

    @ObservationIgnored private let userDefaults: UserDefaults

    /// 选中后直接粘贴到之前的应用；关闭时只写回剪贴板，由用户自己按 ⌘V。
    var autoPaste: Bool {
        didSet { userDefaults.set(autoPaste, forKey: Self.autoPasteKey) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        autoPaste = userDefaults.object(forKey: Self.autoPasteKey) as? Bool ?? true
    }
}
