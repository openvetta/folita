import AppKit
import Observation

/// 可选的应用图标。图像由 scripts/icons/export-app-icons.sh 从 design/app-icons 生成。
enum AppIconOption: String, CaseIterable, Identifiable, Sendable {
    case fox, dog, chick, cat, panda, rabbit, frog, pig, bear, penguin, koala, snake

    static let defaultOption = AppIconOption.fox

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .fox: "Fox"
        case .dog: "Dog"
        case .chick: "Chick"
        case .cat: "Black Cat"
        case .panda: "Panda"
        case .rabbit: "Rabbit"
        case .frog: "Frog"
        case .pig: "Pig"
        case .bear: "Bear"
        case .penguin: "Penguin"
        case .koala: "Koala"
        case .snake: "Snake"
        }
    }

    /// 已按系统蒙层裁成圆角矩形、铺满画布的图标，用于设置页缩略图。
    var image: NSImage? { NSImage(named: "AppIcon-\(rawValue)") }

    /// 运行时 Dock 图标。系统图标网格在 1024 画布中留 100 的透明边距，补齐后才与其他图标等大。
    var dockImage: NSImage? {
        guard let image else { return nil }
        let canvas = NSSize(width: 1024, height: 1024)
        return NSImage(size: canvas, flipped: false) { rect in
            image.draw(in: rect.insetBy(dx: rect.width * 100 / 1024, dy: rect.height * 100 / 1024))
            return true
        }
    }
}

/// 应用图标设置。应用在沙盒内无法改写自身 bundle，所以只替换运行期间的 Dock 图标；
/// 默认图标交还系统渲染，以保留 Dock 的深色、着色等外观模式。
@MainActor
@Observable
final class AppIconSettings {
    static let userDefaultsKey = "FolitaAppIcon"

    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let setApplicationIcon: @MainActor (NSImage?) -> Void

    var selection: AppIconOption {
        didSet {
            userDefaults.set(selection.rawValue, forKey: Self.userDefaultsKey)
            apply()
        }
    }

    init(
        userDefaults: UserDefaults = .standard,
        setApplicationIcon: @escaping @MainActor (NSImage?) -> Void = { NSApp.applicationIconImage = $0 }
    ) {
        self.userDefaults = userDefaults
        self.setApplicationIcon = setApplicationIcon
        selection = userDefaults.string(forKey: Self.userDefaultsKey).flatMap(AppIconOption.init) ?? .defaultOption
    }

    /// 启动时与切换后调用；传 nil 让系统恢复 bundle 中的默认图标。
    func apply() {
        setApplicationIcon(selection == .defaultOption ? nil : selection.dockImage)
    }
}
