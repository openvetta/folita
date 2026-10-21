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

    /// 已按系统蒙层裁成圆角矩形、铺满画布的图标：设置页缩略图、剪贴面板顶标与关于页都用它。
    var image: NSImage? { NSImage(named: "AppIcon-\(rawValue)") }

    /// 菜单栏图标的标准尺寸（点）。菜单栏高度固定，图标按这个边长绘制。
    static let menuBarSide: CGFloat = 18

    /// 菜单栏图标：把已蒙层的图标按菜单栏尺寸重新绘制。
    /// 直接交出新原图会让菜单栏按 512 点渲染，状态栏项会撑满整条菜单栏；
    /// 同时不加模板渲染，保留彩色。
    var menuBarImage: NSImage? {
        guard let image else { return nil }
        let side = Self.menuBarSide
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            image.draw(in: rect)
            return true
        }
    }
}

/// 应用图标设置。应用在沙盒内无法改写自身 bundle，所以只在运行期间替换应用图标：
/// 菜单栏图标、剪贴面板顶标与关于页都跟随这份选择。
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

    /// 启动时与切换后调用：把所选图标交给系统，应用内的弹窗也跟随这份选择。
    func apply() {
        setApplicationIcon(selection.image)
    }
}
