import Foundation
import Observation

/// 剪贴面板呼出时出现的位置。
enum PanelPlacement: String, CaseIterable, Identifiable {
    case topCenter
    case center
    case cursor

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .topCenter: "Top of the screen"
        case .center: "Center of the screen"
        case .cursor: "At the cursor"
        }
    }
}

/// 呼出位置的用户选择。
@MainActor
@Observable
final class PanelPlacementSettings {
    static let placementKey = "FolitaPanelPlacement"
    static let defaultPlacement = PanelPlacement.topCenter

    @ObservationIgnored private let userDefaults: UserDefaults

    var placement: PanelPlacement {
        didSet { userDefaults.set(placement.rawValue, forKey: Self.placementKey) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        placement = userDefaults.string(forKey: Self.placementKey).flatMap(PanelPlacement.init(rawValue:))
            ?? Self.defaultPlacement
    }
}
