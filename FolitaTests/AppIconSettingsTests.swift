import AppKit
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct AppIconSettingsTests {
    private func rasterize(_ image: NSImage, side: Int = 1024) throws -> NSBitmapImageRep {
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    @Test func defaultsToFox() throws {
        let services = TestServices()
        #expect(services.appIcon.selection == .fox)

        services.appIcon.apply()
        #expect(services.appliedIcons.count == 1)
        #expect(try #require(services.appliedIcons[0]) == services.appIcon.selection.image)
    }

    /// 常见流程：通用设置里换图标 → 运行期应用图标立即跟上，重启后仍是所选图标。
    @Test func choosingIconAppliesImmediatelyAndSurvivesRelaunch() throws {
        let services = TestServices()
        services.appIcon.selection = .penguin
        let applied = try #require(services.appliedIcons.last ?? nil)
        #expect(applied.size == AppIconOption.penguin.image?.size)

        // 重新启动：新实例读取已保存的选择，并在启动时应用。
        var relaunched: [NSImage?] = []
        let restored = AppIconSettings(userDefaults: services.defaults) { relaunched.append($0) }
        #expect(restored.selection == .penguin)
        restored.apply()
        #expect(relaunched.count == 1 && relaunched[0] != nil)

        // 换回狐狸时同样立即生效。
        restored.selection = .fox
        #expect(relaunched.count == 2 && relaunched[1] != nil)
        #expect(AppIconSettings(userDefaults: services.defaults) { _ in }.selection == .fox)
    }

    @Test func unknownStoredValueFallsBackToFox() {
        let services = TestServices()
        services.defaults.set("unicorn", forKey: AppIconSettings.userDefaultsKey)
        #expect(AppIconSettings(userDefaults: services.defaults) { _ in }.selection == .fox)
    }

    @Test(arguments: AppIconOption.allCases)
    func everyOptionHasMaskedImage(option: AppIconOption) throws {
        let rep = try rasterize(try #require(option.image), side: 512)
        // 系统蒙层裁掉了四角，角落透明、边缘中点与中心不透明。
        #expect(try #require(rep.colorAt(x: 2, y: 2)).alphaComponent == 0)
        #expect(try #require(rep.colorAt(x: 4, y: 256)).alphaComponent > 0.9)
        #expect(try #require(rep.colorAt(x: 256, y: 256)).alphaComponent == 1)
    }

    /// 菜单栏图标：按菜单栏尺寸（18 pt）绘制，而不是把 512 点原图直接交出去（会把状态栏项撑满整条菜单栏）；
    /// 且不加模板渲染，保留彩色。
    @Test(arguments: AppIconOption.allCases)
    func everyOptionProvidesColoredMenuBarIconAtMenuBarSize(option: AppIconOption) throws {
        let icon = try #require(option.menuBarImage)
        #expect(icon.size == NSSize(width: 18, height: 18))
        #expect(icon.isTemplate == false)

        let rep = try rasterize(icon, side: 512)
        #expect(try #require(rep.colorAt(x: 4, y: 256)).alphaComponent > 0.9)
        #expect(try #require(rep.colorAt(x: 2, y: 2)).alphaComponent == 0)
    }

    @Test(arguments: [
        ("zh-Hans", ColorScheme.light), ("zh-Hans", .dark), ("en", .light), ("en", .dark),
    ])
    func pickerLaysOut(locale: String, scheme: ColorScheme) {
        let services = TestServices()
        let host = NSHostingView(rootView: AppIconPicker().testServices(services, locale: locale, scheme: scheme))
        host.frame = CGRect(x: 0, y: 0, width: 480, height: 200)
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize.height > 100)

        services.appIcon.selection = .koala
        host.layoutSubtreeIfNeeded()
        #expect(services.appliedIcons.count == 1)
    }
}
