import AppKit
import ImageIO
import UniformTypeIdentifiers

/// 详情区展示的派生信息，按需从一条历史的原始格式计算。
struct ClipDetails: Equatable {
    var category: ClipCategory
    /// 所有格式数据的总大小。
    var byteCount: Int
    var text: String?
    var characterCount: Int?
    var lineCount: Int?
    /// 只读取图片文件头得到的像素尺寸，不解码整张图。
    var pixelSize: CGSize?
    var fileURLs: [URL] = []
    /// 复制的恰好是一个图片文件时的文件地址，列表与详情据此显示图片本身而不是文件图标。
    var imageFileURL: URL?
    var color: RGBAColor?
    var link: URL?
    var colorFormat: ColorFormat?
    var linkTarget: LinkTarget?
    /// 文本开头一段里出现的邮件地址（按出现顺序、已去重）。链接与颜色条目不提取：网址里的 @ 不是收件人。
    var emails: [String] = []

    init(contents: [ClipContent], category: ClipCategory) {
        self.category = category
        byteCount = contents.reduce(0) { $0 + $1.data.count }
        fileURLs = ClipClassification.fileURLs(in: contents) ?? []

        if category.isTextual, let text = ClipClassification.plainText(in: contents) ?? ClipboardWriter.plainText(from: contents) {
            self.text = text
            characterCount = text.count
            lineCount = text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if category == .color {
                color = RGBAColor(parsing: trimmed)
                colorFormat = ColorFormat.detect(trimmed)
            }
            if category == .link {
                link = URL(string: trimmed)
                linkTarget = link.flatMap { LinkTarget(url: $0) }
            } else if category != .color {
                emails = EmailAddresses.all(in: text)
            }
        }

        if let url = Self.imageFileURL(in: contents) {
            imageFileURL = url
        }

        if let image = contents.first(where: { ClipboardCapture.imageTypes.contains($0.type) }) {
            pixelSize = Self.pixelSize(of: image.data)
        }
    }

    /// 内容恰好是一个图片文件时返回其地址；多个文件或非图片文件返回 nil。
    static func imageFileURL(in contents: [ClipContent]) -> URL? {
        guard let urls = ClipClassification.fileURLs(in: contents), urls.count == 1, let url = urls.first,
              UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
        else { return nil }
        return url
    }

    static func pixelSize(of data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return CGSize(width: width, height: height)
    }
}

/// 从颜色文本解析出的分量，取值 0...1。
struct RGBAColor: Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    /// 支持 #RGB、#RGBA、#RRGGBB、#RRGGBBAA、rgb()/rgba() 与 hsl()/hsla()。
    init?(parsing text: String) {
        let text = text.trimmingCharacters(in: .whitespaces).lowercased()
        if text.hasPrefix("#") {
            guard let parsed = Self.hex(String(text.dropFirst())) else { return nil }
            self = parsed
        } else if let match = text.wholeMatch(of: /(rgba?|hsla?)\((.*)\)/) {
            // 逗号分隔与 CSS 新语法（空格分隔、`/` 后跟透明度）都接受。
            let values = match.2
                .replacingOccurrences(of: "/", with: " ")
                .replacingOccurrences(of: ",", with: " ")
                .split(whereSeparator: \.isWhitespace).map(String.init)
            guard values.count == 3 || values.count == 4 else { return nil }
            let alpha = values.count == 4 ? Self.component(values[3], scale: 1) : 1
            if match.1.hasPrefix("rgb") {
                guard let r = Self.component(values[0], scale: 255),
                      let g = Self.component(values[1], scale: 255),
                      let b = Self.component(values[2], scale: 255),
                      let alpha else { return nil }
                self.init(red: r, green: g, blue: b, alpha: alpha)
            } else {
                let hueText = values[0].hasSuffix("deg") ? String(values[0].dropLast(3)) : values[0]
                guard let hue = Double(hueText),
                      let s = Self.component(values[1], scale: 100),
                      let l = Self.component(values[2], scale: 100),
                      let alpha else { return nil }
                self = Self.fromHSL(hue: hue, saturation: s, lightness: l, alpha: alpha)
            }
        } else {
            return nil
        }
    }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    private static func hex(_ digits: String) -> RGBAColor? {
        let expanded: String
        switch digits.count {
        case 3, 4: expanded = digits.map { "\($0)\($0)" }.joined()
        case 6, 8: expanded = digits
        default: return nil
        }
        guard let value = UInt64(expanded, radix: 16) else { return nil }
        let hasAlpha = expanded.count == 8
        let shift: UInt64 = hasAlpha ? 8 : 0
        func byte(_ offset: UInt64) -> Double { Double((value >> (offset + shift)) & 0xFF) / 255 }
        return RGBAColor(
            red: byte(16),
            green: byte(8),
            blue: byte(0),
            alpha: hasAlpha ? Double(value & 0xFF) / 255 : 1
        )
    }

    /// "50%" 按百分比解析，否则按给定满量程换算到 0...1。
    private static func component(_ text: String, scale: Double) -> Double? {
        if text.hasSuffix("%") {
            return Double(text.dropLast()).map { min(max($0 / 100, 0), 1) }
        }
        return Double(text).map { min(max($0 / scale, 0), 1) }
    }

    private static func fromHSL(hue: Double, saturation s: Double, lightness l: Double, alpha: Double) -> RGBAColor {
        let h = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
        guard s > 0 else { return RGBAColor(red: l, green: l, blue: l, alpha: alpha) }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        func channel(_ t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1 / 6 { return p + (q - p) * 6 * t }
            if t < 1 / 2 { return q }
            if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
            return p
        }
        return RGBAColor(red: channel(h + 1 / 3), green: channel(h), blue: channel(h - 1 / 3), alpha: alpha)
    }
}
