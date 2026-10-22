import SwiftUI

/// 手动添加文本到收藏夹：一段文本 + 一个分组，保存后直接成为该分组的收藏。
///
/// 收藏夹原先只能把已复制的剪贴内容收藏进来。这个入口让用户直接录入想长期保存的
/// 片段（常用回复、命令、地址等），不必先复制一次。视图只负责输入与校验，写入交给
/// `ClipboardHistoryStore.addFavoriteText`，与剪贴来源共用同一份收藏数据。
struct AddFavoriteTextSheet: View {
    let tabs: [FavoriteTab]
    /// 打开时预选的分组；为 nil 或不在 `tabs` 中时选中第一个分组。
    let initialTabID: UUID?

    var onSave: (String, UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var selectedTabID: UUID
    @FocusState private var isEditorFocused: Bool

    init(tabs: [FavoriteTab], initialTabID: UUID?, onSave: @escaping (String, UUID) -> Void) {
        self.tabs = tabs
        self.initialTabID = initialTabID
        self.onSave = onSave
        let resolved = tabs.contains(where: { $0.id == initialTabID }) ? initialTabID : tabs.first?.id
        _selectedTabID = State(initialValue: resolved ?? UUID())
    }

    /// 只有分组非空且文本不是纯空白时才能保存。
    private var canSave: Bool {
        !tabs.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Text to Favorites")
                .font(.headline)

            editor
                .frame(minHeight: 160)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.separator, lineWidth: 1)
                }

            if tabs.isEmpty {
                Text("Create a group first to save text here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                groupPicker
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear { isEditorFocused = true }
    }

    private var editor: some View {
        // 用 system 字体与深色模式自适应的语义色，深浅外观都不硬编码颜色。
        TextEditor(text: $text)
            .font(.system(size: 13))
            .scrollContentBackground(.hidden)
            .padding(6)
            .focused($isEditorFocused)
            .accessibilityLabel(Text("Text"))
    }

    private var groupPicker: some View {
        Picker("Group", selection: $selectedTabID) {
            ForEach(tabs) { tab in
                Text(verbatim: tab.name).tag(tab.id)
            }
        }
        .pickerStyle(.menu)
    }

    private func save() {
        guard canSave, let tab = tabs.first(where: { $0.id == selectedTabID }) else { return }
        onSave(text, tab.id)
        dismiss()
    }
}
