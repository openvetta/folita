import Foundation
@testable import Folita

/// 基于内存库的面板模型，按顺序复制给定文本（最后一条排在最前）。
@MainActor
func makePanelModel(copying texts: [String] = []) -> ClipboardPanelModel {
    let store = ClipboardHistoryStore(container: HistoryStorage.makeInMemoryContainer(), limit: { 500 })
    for text in texts {
        store.record(CapturedClip(contents: [ClipContent(type: .string, data: Data(text.utf8))], sourceBundleID: nil))
    }
    return ClipboardPanelModel(store: store)
}
