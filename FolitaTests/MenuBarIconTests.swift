import AppKit
import SwiftUI
import Testing
@testable import Folita

/// 菜单栏图标：显示通用设置里所选的应用图标，彩色渲染。
@MainActor
struct MenuBarIconTests {
    private func render(_ view: some View) throws -> NSBitmapImageRep {
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(x: 0, y: 0, width: MenuBarIcon.size, height: MenuBarIcon.size)
        host.layoutSubtreeIfNeeded()

        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        return rep
    }

    /// 应用以 LSUIElement 运行：没有 Dock 图标，只以菜单栏图标常驻。
    @Test func appRunsAsMenuBarAccessory() throws {
        let info = try #require(Bundle.main.infoDictionary)
        #expect(info["LSUIElement"] as? Bool == true)
    }

    /// 位图里最鲜艳的那个像素：用来区分彩色图标与单色剪影。
    private func maxChroma(in rep: NSBitmapImageRep) -> CGFloat {
        var result: CGFloat = 0
        for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
            for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.9
                else { continue }
                let channels = [color.redComponent, color.greenComponent, color.blueComponent]
                result = max(result, channels.max()! - channels.min()!)
            }
        }
        return result
    }

    @Test(arguments: [
        ("zh-Hans", ColorScheme.light), ("zh-Hans", .dark), ("en", .light), ("en", .dark),
    ])
    func menuBarIconLaysOut(locale: String, scheme: ColorScheme) {
        let services = TestServices()
        let host = NSHostingView(rootView: MenuBarIcon(appIconSettings: services.appIcon).testServices(services, locale: locale, scheme: scheme))
        host.layoutSubtreeIfNeeded()

        #expect(host.fittingSize == CGSize(width: MenuBarIcon.size, height: MenuBarIcon.size))
    }

    /// 常见流程：菜单栏图标来自通用设置里的选择，换图标后画出的图案随之改变。
    @Test func menuBarIconFollowsSelectedAppIcon() throws {
        let services = TestServices()

        services.appIcon.selection = .fox
        let fox = try render(MenuBarIcon(appIconSettings: services.appIcon).testServices(services, locale: "en"))

        services.appIcon.selection = .penguin
        let penguin = try render(MenuBarIcon(appIconSettings: services.appIcon).testServices(services, locale: "en"))

        let center = try #require(fox.colorAt(x: fox.pixelsWide / 2, y: fox.pixelsHigh / 2))
        #expect(center.alphaComponent > 0.9)
        #expect(fox.tiffRepresentation != penguin.tiffRepresentation)
    }

    /// 彩色而不是菜单栏默认的单色模板：渲染结果里存在明显带饱和度的像素。
    @Test func menuBarIconKeepsColor() throws {
        let services = TestServices()
        let rep = try render(MenuBarIcon(appIconSettings: services.appIcon).testServices(services, locale: "en"))
        #expect(maxChroma(in: rep) > 0.2)
    }
}
