import AppKit
import UniformTypeIdentifiers

/// 文件条目在列表里的图标：按扩展名取系统的文档类型图标（PDF、Word、压缩包等），
/// 无法识别的扩展名、多个文件等情况落到通用文档图标，不依赖文件仍然存在。
enum FileTypeIcon {
    /// 决定图标所用的内容类型。单个文件按扩展名；目录用文件夹；多个文件或无法识别时用通用数据类型兜底。
    static func contentType(for urls: [URL]) -> UTType {
        guard urls.count == 1, let url = urls.first else { return .data }
        if url.hasDirectoryPath { return .folder }
        return UTType(filenameExtension: url.pathExtension) ?? .data
    }

    @MainActor private static var cache: [String: NSImage] = [:]

    @MainActor
    static func image(for urls: [URL]) -> NSImage {
        let type = contentType(for: urls)
        if let cached = cache[type.identifier] { return cached }
        let icon = NSWorkspace.shared.icon(for: type)
        cache[type.identifier] = icon
        return icon
    }
}
