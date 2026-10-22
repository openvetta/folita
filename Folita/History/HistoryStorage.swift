import Foundation
import os
import SwiftData

/// 打开剪贴历史数据库。库文件损坏时备份后重建，而不是让应用无法启动。
enum HistoryStorage {
    struct Opened {
        let container: ModelContainer
        /// 非空表示原数据库无法打开，已被移到这里。
        let backupURL: URL?
    }

    /// 库文件及 SwiftData 的外置数据都放在这个目录里，损坏时整体改名备份。
    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Folita/History", directoryHint: .isDirectory)
    }

    private static let logger = Logger(subsystem: "app.folita.Folita", category: "history")

    static func open(in directory: URL = defaultDirectory, now: Date = .now) -> Opened {
        do {
            return Opened(container: try makeContainer(in: directory), backupURL: nil)
        } catch {
            logger.error("Opening history failed, backing up: \(error.localizedDescription, privacy: .public)")
        }

        do {
            let backup = try backUp(directory, now: now)
            return Opened(container: try makeContainer(in: directory), backupURL: backup)
        } catch {
            // 连重建都失败时退回内存库：本次运行仍可使用，只是不跨重启保留。
            logger.fault("Recreating history failed: \(error.localizedDescription, privacy: .public)")
            return Opened(container: makeInMemoryContainer(), backupURL: nil)
        }
    }

    /// 历史目录占用的磁盘空间（含外置的大数据），目录不存在时为 0。
    static func diskUsage(of directory: URL = defaultDirectory) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            total += Int64(values?.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    static func makeInMemoryContainer() -> ModelContainer {
        do {
            return try ModelContainer(
                for: HistoryItem.self, FavoriteTab.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("In-memory history store cannot be created: \(error)")
        }
    }

    private static func makeContainer(in directory: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let configuration = ModelConfiguration(url: directory.appending(path: "History.store"))
        return try ModelContainer(for: HistoryItem.self, FavoriteTab.self, configurations: configuration)
    }

    private static func backUp(_ directory: URL, now: Date) throws -> URL {
        let stamp = now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacingOccurrences(of: ":", with: "")
        let backup = directory.deletingLastPathComponent()
            .appending(path: "\(directory.lastPathComponent)-corrupted-\(stamp)", directoryHint: .isDirectory)
        try FileManager.default.moveItem(at: directory, to: backup)
        return backup
    }
}
