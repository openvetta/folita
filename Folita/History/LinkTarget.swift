import Foundation

/// 常见站点链接的结构化信息，只从网址本身推导，不请求网络。
struct LinkTarget: Equatable {
    enum Brand: Equatable {
        case github
        case x
        case youtube

        /// 品牌名不随语言变化。
        var name: String {
            switch self {
            case .github: "GitHub"
            case .x: "X"
            case .youtube: "YouTube"
            }
        }
    }

    enum Kind: Equatable {
        case repository
        case profile
        case gist
        case post
        case video
        case channel
        case page

        var title: LocalizedStringResource {
            switch self {
            case .repository: "Repository"
            case .profile: "Profile"
            case .gist: "Gist"
            case .post: "Post"
            case .video: "Video"
            case .channel: "Channel"
            case .page: "Link"
            }
        }
    }

    var brand: Brand
    var kind: Kind
    /// 卡片主标题：仓库全名、账号、频道名或视频 ID。
    var title: String

    private static let githubReserved: Set<String> = [
        "orgs", "settings", "marketplace", "topics", "explore", "sponsors", "notifications", "features",
        "pricing", "login", "join", "about", "apps", "collections", "trending", "organizations", "search", "new",
    ]
    private static let xReserved: Set<String> = [
        "home", "explore", "search", "notifications", "messages", "settings", "i", "compose", "login", "hashtag",
    ]

    /// 不是已知站点时返回 nil。
    init?(url: URL) {
        guard var host = url.host()?.lowercased() else { return nil }
        for prefix in ["www.", "m.", "mobile.", "music."] where host.hasPrefix(prefix) {
            host.removeFirst(prefix.count)
        }
        let path = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "github.com":
            self = Self.github(path)
        case "gist.github.com":
            self.init(brand: .github, kind: .gist, title: path.last ?? "Gist")
        case "x.com", "twitter.com":
            self = Self.x(path)
        case "youtube.com":
            self = Self.youtube(path, query: url)
        case "youtu.be":
            guard let id = path.first else { return nil }
            self.init(brand: .youtube, kind: .video, title: id)
        default:
            return nil
        }
    }

    init(brand: Brand, kind: Kind, title: String) {
        self.brand = brand
        self.kind = kind
        self.title = title
    }

    private static func github(_ path: [String]) -> LinkTarget {
        guard let owner = path.first, !githubReserved.contains(owner.lowercased()) else {
            return LinkTarget(brand: .github, kind: .page, title: Brand.github.name)
        }
        guard path.count >= 2 else { return LinkTarget(brand: .github, kind: .profile, title: owner) }
        let repository = path[1].hasSuffix(".git") ? String(path[1].dropLast(4)) : path[1]
        return LinkTarget(brand: .github, kind: .repository, title: "\(owner)/\(repository)")
    }

    private static func x(_ path: [String]) -> LinkTarget {
        guard let handle = path.first, !xReserved.contains(handle.lowercased()) else {
            return LinkTarget(brand: .x, kind: .page, title: Brand.x.name)
        }
        let isPost = path.count >= 3 && path[1].lowercased() == "status"
        return LinkTarget(brand: .x, kind: isPost ? .post : .profile, title: "@\(handle)")
    }

    private static func youtube(_ path: [String], query url: URL) -> LinkTarget {
        let page = LinkTarget(brand: .youtube, kind: .page, title: Brand.youtube.name)
        guard let first = path.first else { return page }
        if first == "watch" {
            let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "v" }?.value
            return id.map { LinkTarget(brand: .youtube, kind: .video, title: $0) } ?? page
        }
        if ["shorts", "embed", "live"].contains(first), path.count >= 2 {
            return LinkTarget(brand: .youtube, kind: .video, title: path[1])
        }
        if first.hasPrefix("@") { return LinkTarget(brand: .youtube, kind: .channel, title: first) }
        if ["channel", "c", "user"].contains(first), path.count >= 2 {
            return LinkTarget(brand: .youtube, kind: .channel, title: path[1])
        }
        return page
    }
}
