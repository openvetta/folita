import AppKit
import ImageIO

/// 列表行用到的图片：剪贴图片的缩略图、来源应用图标。
enum ClipPreviewImages {
    /// 在后台线程按目标尺寸解码缩略图，避免大图在主线程整张解码。
    nonisolated static func thumbnail(from data: Data, maxPixelSize: Int) async -> CGImage? {
        await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }.value
    }

    @MainActor private static var appIcons: [String: NSImage] = [:]

    /// 来源应用图标；应用已卸载时返回 nil。
    @MainActor
    static func appIcon(bundleID: String) -> NSImage? {
        if let cached = appIcons[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
        appIcons[bundleID] = icon
        return icon
    }

    /// 来源应用名称；应用已卸载时返回 nil。
    @MainActor
    static func appName(bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let name = FileManager.default.displayName(atPath: url.path(percentEncoded: false))
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
}
