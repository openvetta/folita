import Foundation
import Observation
import os
import ServiceManagement

/// 开机自启。状态以系统登录项为准，不另存一份设置。
@MainActor
@Observable
final class LaunchAtLogin {
    struct Backend {
        var status: @MainActor () -> SMAppService.Status
        var setEnabled: @MainActor (Bool) throws -> Void

        static let system = Backend(
            status: { SMAppService.mainApp.status },
            setEnabled: { enabled in
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            }
        )
    }

    private(set) var status: SMAppService.Status
    /// 最近一次切换失败的原因，展示给用户。
    private(set) var lastError: String?

    @ObservationIgnored private let backend: Backend
    @ObservationIgnored private let logger = Logger(subsystem: "app.folita.Folita", category: "launch-at-login")

    init(backend: Backend = .system) {
        self.backend = backend
        status = backend.status()
    }

    /// 用户需要在系统设置的登录项中批准时也视为已开启，避免开关来回跳。
    var isEnabled: Bool { status == .enabled || status == .requiresApproval }
    var needsApproval: Bool { status == .requiresApproval }

    func setEnabled(_ enabled: Bool) {
        do {
            try backend.setEnabled(enabled)
            lastError = nil
        } catch {
            logger.error("Updating login item failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
        refresh()
    }

    func refresh() {
        status = backend.status()
    }
}
