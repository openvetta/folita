import AppKit
import UniformTypeIdentifiers

/// 复制单个图片文件时，趁复制刚发生把图片内容读下来。
/// 微信等应用只放文件地址，文件在它自己的容器里，事后 Folita 无权读取；
/// 通过 `readObjects` 取得的地址附带系统授予的临时访问权限，此刻读才有机会成功。
enum ImageFileSnapshot {
    private static let typesByUTType: [(UTType, NSPasteboard.PasteboardType)] = [
        (.png, .png), (.jpeg, .jpeg), (.heic, .heic), (.tiff, .tiff),
    ]

    /// 剪贴板上恰好是一个受支持的图片文件、且没有任何图片数据时，返回读到的图片内容；否则 nil。
    static func content(from pasteboard: NSPasteboard, existing: [ClipContent]) -> ClipContent? {
        guard !existing.contains(where: { ClipboardCapture.imageTypes.contains($0.type) }),
              ClipClassification.fileURLs(in: existing)?.count == 1,
              let urls = pasteboard.readObjects(
                  forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]
              ) as? [URL],
              urls.count == 1, let url = urls.first
        else { return nil }
        return content(ofFileAt: url)
    }

    static func content(ofFileAt url: URL) -> ClipContent? {
        guard let fileType = UTType(filenameExtension: url.pathExtension),
              let type = typesByUTType.first(where: { fileType.conforms(to: $0.0) })?.1,
              let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0, size <= ClipboardCapture.maxClipBytes,
              let data = try? Data(contentsOf: url)
        else { return nil }
        return ClipContent(type: type, data: data)
    }
}
