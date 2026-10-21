import AppKit

/// 一条剪贴记录的类别，用于列表图标与类型筛选。
/// link / color / email 是从纯文本派生的分类，底层数据仍是文本。
enum ClipCategory: String, CaseIterable, Sendable {
    case text
    case richText
    case image
    case file
    case link
    case color
    case email

    var isTextual: Bool {
        switch self {
        case .text, .richText, .link, .color, .email: true
        case .image, .file: false
        }
    }
}

enum ClipClassification {
    /// 列表标题的最大长度，超长文本只影响展示，不影响回填。
    static let maxTitleLength = 1_000

    static func category(of contents: [ClipContent]) -> ClipCategory {
        let types = Set(contents.map(\.type))
        if types.contains(.fileURL) { return .file }
        if let text = plainText(in: contents) {
            if !types.isDisjoint(with: [.rtf, .html]) { return .richText }
            return derivedCategory(ofText: text)
        }
        if !types.isDisjoint(with: ClipboardCapture.imageTypes) { return .image }
        return .richText
    }

    /// 整段文本（去掉首尾空白）恰好是一个链接、邮箱或颜色值时才归入派生分类。
    static func derivedCategory(ofText text: String) -> ClipCategory {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isNewline) else { return .text }
        if isColor(trimmed) { return .color }
        if isEmail(trimmed) { return .email }
        if isLink(trimmed) { return .link }
        return .text
    }

    static func title(for contents: [ClipContent]) -> String {
        let raw: String
        if let urls = fileURLs(in: contents), !urls.isEmpty {
            raw = urls.map { $0.path(percentEncoded: false) }.joined(separator: "\n")
        } else if let text = plainText(in: contents) {
            raw = text
        } else if let data = contents.first(where: { $0.type == .rtf })?.data,
                  let attributed = NSAttributedString(rtf: data, documentAttributes: nil) {
            raw = attributed.string
        } else {
            raw = ""
        }
        return sanitizedTitle(raw)
    }

    /// U+FFFC（富文本内嵌附件的占位符）连续出现在非拉丁文本旁时，会让 macOS 26 的
    /// CoreText 截断排版陷入死循环、CPU 100% 且无法恢复（Maccy issue #1520）。
    /// 按 Unicode scalar 过滤：它与组合字符会构成同一个字素簇，按 Character 过滤会漏掉。
    static func sanitizedTitle(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars where scalar != "\u{FFFC}" {
            scalars.append(scalar)
        }
        let cleaned = String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(maxTitleLength))
    }

    static func plainText(in contents: [ClipContent]) -> String? {
        contents.first { $0.type == .string }.map { String(decoding: $0.data, as: UTF8.self) }
    }

    static func fileURLs(in contents: [ClipContent]) -> [URL]? {
        let urls = contents
            .filter { $0.type == .fileURL }
            .compactMap { URL(dataRepresentation: $0.data, relativeTo: nil, isAbsolute: true) }
        return urls.isEmpty ? nil : urls
    }

    private static func isLink(_ text: String) -> Bool {
        guard !text.contains(where: \.isWhitespace),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https"].contains(scheme) && url.host() != nil
    }

    private static func isEmail(_ text: String) -> Bool {
        text.wholeMatch(of: /[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/) != nil
    }

    private static func isColor(_ text: String) -> Bool {
        // 以解析器为唯一事实源：能解析成颜色的格式都归为颜色，也就都能互相转换。
        RGBAColor(parsing: text) != nil
    }
}
