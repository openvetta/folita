import AppKit
import ServiceManagement
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct GeneralSettingsTests {
    private struct LoginItemError: Error {}

    @Test func launchAtLoginTogglesLoginItem() {
        var status = SMAppService.Status.notRegistered
        let launch = LaunchAtLogin(backend: .init(
            status: { status },
            setEnabled: { status = $0 ? .enabled : .notRegistered }
        ))
        #expect(!launch.isEnabled)

        launch.setEnabled(true)
        #expect(launch.isEnabled)
        #expect(launch.lastError == nil)

        launch.setEnabled(false)
        #expect(!launch.isEnabled)
    }

    @Test func launchAtLoginReportsFailureAndApproval() {
        var status = SMAppService.Status.notRegistered
        let launch = LaunchAtLogin(backend: .init(
            status: { status },
            setEnabled: { _ in throw LoginItemError() }
        ))
        launch.setEnabled(true)
        #expect(!launch.isEnabled)
        #expect(launch.lastError != nil)

        status = .requiresApproval
        launch.refresh()
        #expect(launch.isEnabled)
        #expect(launch.needsApproval)
    }

    @Test(arguments: [
        ("zh-Hans", ColorScheme.light, true), ("zh-Hans", .dark, false),
        ("en", .light, false), ("en", .dark, true),
    ])
    func laysOutWithAndWithoutPermission(locale: String, scheme: ColorScheme, trusted: Bool) {
        let services = TestServices()
        services.accessibilityTrusted = trusted
        let host = NSHostingView(rootView: GeneralSettingsView().testServices(services, locale: locale, scheme: scheme))
        host.frame = CGRect(x: 0, y: 0, width: 520, height: 600)
        host.layoutSubtreeIfNeeded()
        #expect(host.frame.width == 520)

        services.paste.autoPaste = false
        host.layoutSubtreeIfNeeded()
        #expect(services.paste.autoPaste == false)
    }

    /// 常见流程：打开通用设置 → 选择“光标位置” → 设置落盘，下次启动仍是该选择。
    @Test(arguments: [
        ("zh-Hans", ColorScheme.light), ("zh-Hans", .dark),
        ("en", .light), ("en", .dark),
    ])
    func placementPickerLaysOutAndPersistsChoice(locale: String, scheme: ColorScheme) {
        let services = TestServices()
        let host = NSHostingView(rootView: GeneralSettingsView().testServices(services, locale: locale, scheme: scheme))
        host.frame = CGRect(x: 0, y: 0, width: 520, height: 700)
        host.layoutSubtreeIfNeeded()
        #expect(services.placement.placement == .topCenter)

        services.placement.placement = .cursor
        host.layoutSubtreeIfNeeded()
        #expect(PanelPlacementSettings(userDefaults: services.defaults).placement == .cursor)
    }
}
