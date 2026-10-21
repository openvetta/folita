import Foundation

/// 应用对外的固定信息。仓库地址同时决定「关于」页链接与自动更新源。
enum AppInfo {
    static let repositoryURL = URL(string: "https://github.com/openvetta/folita")!
    static let licenseURL = URL(string: "https://github.com/openvetta/folita/blob/main/LICENSE")!
    static let copyrightHolder = "nbecloud"

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }
}
