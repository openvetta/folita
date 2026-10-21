import AppKit
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct MainWindowTests {
    /// 让 SwiftUI 完成一次出现/消失回调的派发。
    private func pump() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
    }

    /// 常见流程：打开主面板 → 程序坞出现图标；关掉窗口 → 图标消失，回到只常驻菜单栏。
    @Test func mainPanelTogglesTheDockIcon() {
        let services = TestServices()
        let controller = NSHostingController(rootView: MainPanelView().testServices(services, locale: "en"))
        let window = NSWindow(contentViewController: controller)
        defer { window.close() }

        window.orderFront(nil)
        pump()
        #expect(services.policies == [.regular])

        // 关掉窗口后 SwiftUI 会拆掉内容视图；测试里直接卸下，等同真实关闭。
        window.contentViewController = nil
        pump()
        #expect(services.policies == [.regular, .accessory])
    }

    @Test func dockIconIgnoresRepeatedCalls() {
        var policies: [NSApplication.ActivationPolicy] = []
        let dockIcon = DockIconVisibility { policies.append($0) }

        dockIcon.mainPanelDidAppear()
        dockIcon.mainPanelDidAppear()
        dockIcon.mainPanelDidDisappear()
        dockIcon.mainPanelDidDisappear()

        #expect(policies == [.regular, .accessory])
    }

    /// 面板里的 ⌘, 与菜单栏的「打开主面板」走同一个入口。
    @Test func routerPresentsTheMainWindow() {
        var activations = 0
        let router = MainWindowRouter { activations += 1 }

        // 场景挂载前：仍然把应用带到前台。
        router.present()
        #expect(activations == 1)

        var opened = 0
        router.register { opened += 1 }
        router.present()
        #expect(opened == 1)
        #expect(activations == 2)
    }
}
