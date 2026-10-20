import Foundation
import Observation
import os
import SwiftData

/// 剪贴历史的唯一读写入口，负责去重与按条数上限淘汰。
/// 数据量最多数千条，直接在主 actor 上使用 mainContext（见 docs/adr/0002）。
@MainActor
@Observable
final class ClipboardHistoryStore {
    /// 按最近复制时间倒序。
    private(set) var items: [HistoryItem] = []

    /// mainContext 不持有 container，container 释放后 context 随即失效，必须由这里持有。
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private var context: ModelContext { container.mainContext }
    @ObservationIgnored private let limit: () -> Int
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let logger = Logger(subsystem: "app.folita.Folita", category: "history")

    init(container: ModelContainer, limit: @escaping () -> Int, now: @escaping () -> Date = Date.init) {
        self.container = container
        self.limit = limit
        self.now = now
        reload()
    }

    /// 记录一次复制。内容与已有条目相同时只把那条移到最前，不新增。
    func record(_ clip: CapturedClip) {
        let date = now()
        let hash = HistoryItem.hash(of: clip.contents)
        if let existing = items.first(where: { $0.contentHash == hash }) {
            existing.lastCopiedAt = date
            existing.updatedAt = date
            if let source = clip.sourceBundleID {
                existing.sourceBundleID = source
            }
        } else {
            context.insert(HistoryItem(clip: clip, at: date))
        }
        enforceLimit()
    }

    /// 回填某条历史后把它移到最前。
    func touch(_ item: HistoryItem) {
        let date = now()
        item.lastCopiedAt = date
        item.updatedAt = date
        commit()
    }

    func delete(_ item: HistoryItem) {
        context.delete(item)
        commit()
    }

    func clearAll() {
        items.forEach(context.delete)
        commit()
    }

    /// 超出保留条数时从最旧的开始删除；调小上限后也调用它立即生效。
    func enforceLimit() {
        let sorted = fetchAll()
        for item in sorted.dropFirst(max(limit(), 0)) {
            context.delete(item)
        }
        commit()
    }

    private func commit() {
        do {
            try context.save()
        } catch {
            logger.error("Saving history failed: \(error.localizedDescription, privacy: .public)")
        }
        reload()
    }

    private func reload() {
        items = fetchAll()
    }

    private func fetchAll() -> [HistoryItem] {
        let descriptor = FetchDescriptor<HistoryItem>(sortBy: [SortDescriptor(\.lastCopiedAt, order: .reverse)])
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("Fetching history failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
