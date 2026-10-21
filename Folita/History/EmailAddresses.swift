import Foundation

/// 从文本中找出邮件地址，供「发送邮件」使用。
enum EmailAddresses {
    /// 只扫描开头一段：详情与菜单每次渲染都会算，超长文本不能整段过正则。
    static let scanLimit = 4_000
    /// 菜单里最多列出的地址数，避免二级菜单撑出面板。
    static let maxCount = 8

    /// 按出现顺序返回，忽略大小写去重。
    static func all(in text: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for match in text.prefix(scanLimit).matches(of: /[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/) {
            let address = String(match.output)
            guard seen.insert(address.lowercased()).inserted else { continue }
            result.append(address)
            if result.count == maxCount { break }
        }
        return result
    }

    static func mailtoURL(to address: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        return components.url
    }
}
