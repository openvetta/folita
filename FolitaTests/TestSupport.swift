import Foundation
import ServiceManagement
import SwiftUI
@testable import Folita

/// 基于内存库的面板模型，按顺序复制给定文本（最后一条排在最前）。
@MainActor
func makePanelModel(copying texts: [String] = []) -> ClipboardPanelModel {
    let store = ClipboardHistoryStore(container: HistoryStorage.makeInMemoryContainer(), limit: { 500 })
    for text in texts {
        store.record(CapturedClip(contents: [ClipContent(type: .string, data: Data(text.utf8))], sourceBundleID: nil))
    }
    return ClipboardPanelModel(store: store)
}

/// 设置页需要的全部服务，均使用隔离的 UserDefaults、内存库和假的系统后端。
@MainActor
final class TestServices {
    let suiteName = "FolitaTests.Services.\(UUID().uuidString)"
    let defaults: UserDefaults
    let language: LanguageSettings
    let history: HistorySettings
    let privacy: PrivacySettings
    let paste: PasteSettings
    let store: ClipboardHistoryStore
    let panel: ClipboardPanelController
    var loginItemStatus: SMAppService.Status = .notRegistered
    var accessibilityTrusted = false
    lazy var launchAtLogin = LaunchAtLogin(backend: .init(
        status: { [unowned self] in loginItemStatus },
        setEnabled: { [unowned self] in loginItemStatus = $0 ? .enabled : .notRegistered }
    ))

    init(copying texts: [String] = []) {
        defaults = UserDefaults(suiteName: suiteName)!
        language = LanguageSettings(userDefaults: defaults)
        history = HistorySettings(userDefaults: defaults)
        privacy = PrivacySettings(userDefaults: defaults)
        paste = PasteSettings(userDefaults: defaults)
        let model = makePanelModel(copying: texts)
        store = model.store
        panel = ClipboardPanelController(model: model, languageSettings: language)
    }

    isolated deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    var accessibility: AccessibilityAccess {
        AccessibilityAccess(isTrusted: { [unowned self] in accessibilityTrusted }, requestAccess: {})
    }
}

extension View {
    @MainActor
    func testServices(_ services: TestServices, locale: String, scheme: ColorScheme = .light) -> some View {
        environment(services.panel)
            .environment(services.store)
            .environment(services.history)
            .environment(services.privacy)
            .environment(services.paste)
            .environment(services.launchAtLogin)
            .environment(services.language)
            .environment(\.accessibilityAccess, services.accessibility)
            .environment(\.locale, Locale(identifier: locale))
            .environment(\.colorScheme, scheme)
    }
}
