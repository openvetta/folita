import AppKit

/// 监听剪贴板变化并产出采集结果。
/// 系统不提供剪贴板变化通知，只能轮询 changeCount（见 docs/adr/0001）。
@MainActor
final class ClipboardMonitor {
    static let pollInterval: TimeInterval = 0.5

    private let pasteboard: NSPasteboard
    private let privacy: PrivacySettings
    private let frontmostBundleID: () -> String?
    private let onCapture: (CapturedClip) -> Void
    private var lastChangeCount: Int
    private var timer: Timer?

    init(
        pasteboard: NSPasteboard = .general,
        privacy: PrivacySettings,
        frontmostBundleID: @escaping () -> String? = { NSWorkspace.shared.frontmostApplication?.bundleIdentifier },
        onCapture: @escaping (CapturedClip) -> Void
    ) {
        self.pasteboard = pasteboard
        self.privacy = privacy
        self.frontmostBundleID = frontmostBundleID
        self.onCapture = onCapture
        // 启动前已在剪贴板上的内容不算一次新的复制。
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            // 定时器加在主 RunLoop 上，回调必然在主线程执行。
            MainActor.assumeIsolated { self?.checkNow() }
        }
        // 菜单展开等事件跟踪期间也要继续轮询。
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 检查一次剪贴板；由定时器调用，测试中直接调用以避免等待。
    func checkNow() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount
        guard !privacy.isPaused else { return }

        let items = pasteboard.pasteboardItems ?? []
        // 隐藏/临时标记可能只出现在剪贴板级别的类型列表里，与各项的类型合并后再判断。
        let types = Set(pasteboard.types ?? []).union(items.flatMap(\.types))
        let source = frontmostBundleID()
        guard !ClipboardCapture.shouldSkip(
            types: types,
            sourceBundleID: source,
            ignoredBundleIDs: Set(privacy.ignoredBundleIDs)
        ) else { return }

        let contents = items.map { item in
            ClipboardCapture.supportedTypes.compactMap { type in
                item.types.contains(type) ? item.data(forType: type).map { ClipContent(type: type, data: $0) } : nil
            }
        }
        if let clip = ClipboardCapture.makeClip(items: contents, sourceBundleID: source) {
            onCapture(clip)
        }
    }
}
