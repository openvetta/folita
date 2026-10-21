import Foundation

/// 颜色可互相转换的文本格式。
enum ColorFormat: CaseIterable, Hashable, Sendable {
    case hex
    case rgb
    case hsl

    /// 格式名是技术缩写，各语言一致，不走本地化。
    var title: String {
        switch self {
        case .hex: "HEX"
        case .rgb: "RGB"
        case .hsl: "HSL"
        }
    }

    /// 从颜色文本判断它当前用的格式。
    static func detect(_ text: String) -> ColorFormat? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.hasPrefix("#") { return .hex }
        if text.hasPrefix("rgb") { return .rgb }
        if text.hasPrefix("hsl") { return .hsl }
        return nil
    }

    /// 带透明度（alpha < 1）时输出 8 位 HEX、`rgba()`、`hsla()`，否则输出不带透明度的形式。
    func string(for color: RGBAColor) -> String {
        let hasAlpha = color.alpha < 1
        switch self {
        case .hex:
            let base = String(format: "#%02X%02X%02X", Self.byte(color.red), Self.byte(color.green), Self.byte(color.blue))
            return hasAlpha ? base + String(format: "%02X", Self.byte(color.alpha)) : base
        case .rgb:
            let channels = "\(Self.byte(color.red)), \(Self.byte(color.green)), \(Self.byte(color.blue))"
            return hasAlpha ? "rgba(\(channels), \(Self.alpha(color.alpha)))" : "rgb(\(channels))"
        case .hsl:
            let hsl = color.hsl
            let channels = "\(Int(hsl.hue.rounded()) % 360), \(Int((hsl.saturation * 100).rounded()))%, \(Int((hsl.lightness * 100).rounded()))%"
            return hasAlpha ? "hsla(\(channels), \(Self.alpha(color.alpha)))" : "hsl(\(channels))"
        }
    }

    private static func byte(_ value: Double) -> Int {
        Int((min(max(value, 0), 1) * 255).rounded())
    }

    private static func alpha(_ value: Double) -> String {
        String(format: "%g", (value * 100).rounded() / 100)
    }
}

extension RGBAColor {
    /// 色相 0..<360，饱和度与亮度 0...1。
    var hsl: (hue: Double, saturation: Double, lightness: Double) {
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum
        let lightness = (maximum + minimum) / 2
        guard delta > 0 else { return (0, 0, lightness) }

        let saturation = delta / (1 - abs(2 * lightness - 1))
        var hue: Double
        switch maximum {
        case red: hue = (green - blue) / delta + (green < blue ? 6 : 0)
        case green: hue = (blue - red) / delta + 2
        default: hue = (red - green) / delta + 4
        }
        hue *= 60
        return (hue, saturation, lightness)
    }
}
