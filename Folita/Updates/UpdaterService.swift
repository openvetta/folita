import Foundation
import Observation
import Sparkle

/// 应用内更新。Sparkle 只在这里使用（见 docs/adr/0003）。
@MainActor
@Observable
final class UpdaterService {
    struct Backend {
        var automaticallyChecks: @MainActor () -> Bool
        var setAutomaticallyChecks: @MainActor (Bool) -> Void
        var checkForUpdates: @MainActor () -> Void
    }

    /// 没有配置 EdDSA 公钥的构建（例如外部贡献者的本地构建）不启用更新。
    let isConfigured: Bool

    var automaticallyChecks: Bool {
        didSet { backend?.setAutomaticallyChecks(automaticallyChecks) }
    }

    @ObservationIgnored private let backend: Backend?

    init(backend: Backend?) {
        self.backend = backend
        isConfigured = backend != nil
        automaticallyChecks = backend?.automaticallyChecks() ?? false
    }

    func checkForUpdates() {
        backend?.checkForUpdates()
    }

    /// Info.plist 中的公钥来自构建设置 SPARKLE_PUBLIC_ED_KEY，未设置时为空串。
    nonisolated static func isConfigured(publicKey: String?) -> Bool {
        guard let publicKey = publicKey?.trimmingCharacters(in: .whitespaces) else { return false }
        return !publicKey.isEmpty && !publicKey.hasPrefix("$(")
    }

    static func live(bundle: Bundle = .main) -> UpdaterService {
        guard isConfigured(publicKey: bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String) else {
            return UpdaterService(backend: nil)
        }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        return UpdaterService(backend: Backend(
            automaticallyChecks: { controller.updater.automaticallyChecksForUpdates },
            setAutomaticallyChecks: { controller.updater.automaticallyChecksForUpdates = $0 },
            checkForUpdates: { controller.checkForUpdates(nil) }
        ))
    }
}
