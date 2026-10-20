import AppKit

/// 把一条历史写回剪贴板。
enum ClipboardWriter {
    @MainActor
    static func write(_ contents: [ClipContent], mode: PasteMode, to pasteboard: NSPasteboard) {
        let items: [NSPasteboardItem]
        if mode == .plainText, let text = plainText(from: contents) {
            let item = NSPasteboardItem()
            item.setString(text, forType: .string)
            items = [item]
        } else {
            items = originalItems(from: contents)
        }
        // 标记写在第一项上即可，监听时会合并所有项的类型来判断。
        items.first?.setData(Data(), forType: .folitaOrigin)

        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }

    /// 文件之外的格式放在同一项里还原一次复制；每个额外的文件单独一项，与 Finder 的写法一致。
    private static func originalItems(from contents: [ClipContent]) -> [NSPasteboardItem] {
        let first = NSPasteboardItem()
        var extraFiles: [NSPasteboardItem] = []
        var placedFile = false
        for content in contents {
            if content.type == .fileURL, placedFile {
                let item = NSPasteboardItem()
                item.setData(content.data, forType: .fileURL)
                extraFiles.append(item)
            } else {
                first.setData(content.data, forType: content.type)
                placedFile = placedFile || content.type == .fileURL
            }
        }
        return [first] + extraFiles
    }

    /// 纯文本优先取原始纯文本，没有时从富文本中提取；图片、文件没有纯文本形式。
    static func plainText(from contents: [ClipContent]) -> String? {
        if let text = ClipClassification.plainText(in: contents) { return text }
        for type in [NSPasteboard.PasteboardType.rtf, .html] {
            guard let data = contents.first(where: { $0.type == type })?.data else { continue }
            let documentType: NSAttributedString.DocumentType = type == .rtf ? .rtf : .html
            if let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: documentType, .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil
            ) {
                return attributed.string
            }
        }
        return nil
    }
}
