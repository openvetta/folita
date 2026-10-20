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

    @Test func defaultsToFoxAndKeepsSystemIcon() {
        let services = TestServices()
        #expect(services.appIcon.selection == .fox)

        services.appIcon.apply()
        #expect(services.appliedIcons.count == 1)
        #expect(services.appliedIcons[0] == nil)
    }

    @Test func choosingIconUpdatesDockAndSurvivesRelaunch() throws {
        let services = TestServices()
        services.appIcon.selection = .penguin
        let applied = try #require(services.appliedIcons.last ?? nil)
        #expect(applied.size == NSSize(width: 1024, height: 1024))

        // 重新启动：新实例读取已保存的选择，并在启动时应用。
        var relaunched: [NSImage?] = []
        let restored = AppIconSettings(userDefaults: services.defaults) { relaunched.append($0) }
        #expect(restored.selection == .penguin)
        restored.apply()
        #expect(relaunched.count == 1 && relaunched[0] != nil)

        // 换回狐狸时交还系统渲染的默认图标。
        restored.selection = .fox
        #expect(relaunched.count == 2 && relaunched[1] == nil)
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

    @Test func dockImageKeepsSystemIconMargin() throws {
        let rep = try rasterize(try #require(AppIconOption.dog.dockImage))
        #expect(try #require(rep.colorAt(x: 90, y: 512)).alphaComponent == 0)
        #expect(try #require(rep.colorAt(x: 110, y: 512)).alphaComponent > 0.9)
        #expect(try #require(rep.colorAt(x: 512, y: 934)).alphaComponent == 0)
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
