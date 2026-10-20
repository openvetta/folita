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
    /// 内容指纹，用于去重；唯一性由存储层保证而非数据库约束。
    var contentHash: String = ""

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
