import AppKit
import CryptoKit
import Foundation
import SwiftData

// 建模遵守 CloudKit 约束（见 docs/adr/0002）：不用唯一约束、属性都有默认值、关系可选，
// 为将来用 CKSyncEngine 同步留路。

/// 一次复制。
@Model
final class HistoryItem {
    var id: UUID = UUID()
    var title: String = ""
    var categoryRaw: String = ClipCategory.text.rawValue
    var sourceBundleID: String?
    var firstCopiedAt: Date = Date.distantPast
    var lastCopiedAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    /// 收藏时间。非空即表示已收藏，同时决定收藏夹内的排序（与 `lastCopiedAt` 无关，
    /// 重新复制已收藏内容不会把它在收藏夹里挪到最前）。
    var favoritedAt: Date?
    /// 所属收藏分组；nil 表示未收藏。删除分组时置 nil，条目退回普通历史，不级联删除。
    var favoriteTab: FavoriteTab?

    /// 内容指纹，用于去重；唯一性由存储层保证而非数据库约束。
    var contentHash: String = ""

    /// 是否为用户手动录入的片段（而非从剪贴板复制而来）。
    /// 片段不进入剪贴历史，也不参与「复制」语义：取消收藏即删除，不退回历史。
    var isSnippet: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \HistoryItemContent.item)
    var contents: [HistoryItemContent]? = []

    init(clip: CapturedClip, at date: Date) {
        title = ClipClassification.title(for: clip.contents)
        categoryRaw = ClipClassification.category(of: clip.contents).rawValue
        sourceBundleID = clip.sourceBundleID
        firstCopiedAt = date
        lastCopiedAt = date
        updatedAt = date
        contentHash = Self.hash(of: clip.contents)
        contents = clip.contents.enumerated().map { index, content in
            HistoryItemContent(type: content.type.rawValue, value: content.data, order: index)
        }
    }

    var category: ClipCategory { ClipCategory(rawValue: categoryRaw) ?? .text }

    /// 是否已收藏。`favoritedAt` 与 `favoriteTab` 同时由存储层写入，任一为空都视为未收藏。
    var isFavorited: Bool { favoriteTab != nil && favoritedAt != nil }

    /// 纯文本内容（若有）。
    var plainText: String? {
        ClipClassification.plainText(in: clipContents)
    }

    /// 按采集时的顺序还原的全部格式，回填时原样写回剪贴板。
    var clipContents: [ClipContent] {
        (contents ?? [])
            .sorted { $0.order < $1.order }
            .compactMap { content in
                content.value.map { ClipContent(type: .init(content.type), data: $0) }
            }
    }

    static func hash(of contents: [ClipContent]) -> String {
        var hasher = SHA256()
        for content in contents.sorted(by: { $0.type.rawValue < $1.type.rawValue }) {
            hasher.update(data: Data(content.type.rawValue.utf8))
            hasher.update(data: Data([0]))
            withUnsafeBytes(of: UInt64(content.data.count).littleEndian) { hasher.update(bufferPointer: $0) }
            hasher.update(data: content.data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// 一次复制中的一种剪贴板格式。
@Model
final class HistoryItemContent {
    var type: String = ""
    @Attribute(.externalStorage) var value: Data?
    var order: Int = 0
    var item: HistoryItem?

    init(type: String, value: Data?, order: Int) {
        self.type = type
        self.value = value
        self.order = order
    }
}

/// 收藏夹分组。用户可新建、重命名、删除；「工作」「生活」只在首次启动播种一次，
/// 与用户自建的分组完全平等（见 docs/adr/0006）。
@Model
final class FavoriteTab {
    var id: UUID = UUID()
    var name: String = ""
    /// 新建分组的追加顺序，用于 tab 排的排列；不随收藏时间变化。
    var order: Int = 0
    var createdAt: Date = Date.distantPast

    /// 分组内的条目不参与级联：删除分组时由存储层把 `favoriteTab` 置 nil，剪贴内容本身保留。
    @Relationship(inverse: \HistoryItem.favoriteTab)
    var items: [HistoryItem]? = []

    init(name: String, order: Int, at date: Date) {
        self.name = name
        self.order = order
        createdAt = date
    }
}

