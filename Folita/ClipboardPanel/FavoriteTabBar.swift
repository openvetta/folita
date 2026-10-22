import SwiftUI

/// 收藏夹的分组胶囊排：iOS 风格的横向滚动的胶囊，行尾一个「+」新建分组。
/// 右键胶囊弹出重命名 / 删除。
///
/// 只能靠参数与回调工作，不依赖面板模型：剪贴面板与主窗口两处宿主共用这一套，
/// 分组顺序、选中态与重命名交互因此只有一个事实源。
struct FavoriteTabBar: View {
    let tabs: [FavoriteTab]
    let selectedTabID: UUID?
    /// 正在就地重命名的分组。
    @Binding var renamingTabID: UUID?
    /// 重命名输入框的草稿值。
    @Binding var renameDraft: String

    var select: (UUID?) -> Void
    /// 新建一个待命名的分组；返回 nil 表示没有创建。
    var create: () -> FavoriteTab?
    var rename: (FavoriteTab, String) -> Void
    var delete: (FavoriteTab) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isRenameFocused: Bool

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                pill(title: Text("All"), id: nil)
                ForEach(tabs) { tab in
                    if renamingTabID == tab.id {
                        renameField(for: tab)
                    } else {
                        pill(title: Text(verbatim: tab.name), id: tab.id)
                            .contextMenu {
                                Button("Rename") { beginRenaming(tab) }
                                Button("Delete Group", role: .destructive) { delete(tab) }
                            }
                    }
                }
                addButton
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.never)
        // 分组多到放不下时横向滚动，不折行：面板高度固定，折行会吃掉可见行数。
        .onChange(of: renamingTabID) { _, id in
            isRenameFocused = id != nil
        }
    }

    /// 一个分组胶囊；选中态用实心填充，与 iOS 的分段控件一致。
    private func pill(title: Text, id: UUID?) -> some View {
        let isSelected = selectedTabID == id
        let style = SiriGlassStyle.resolve(for: colorScheme)

        return Button {
            select(id)
        } label: {
            title
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .foregroundStyle(isSelected ? AnyShapeStyle(style.iconForeground) : AnyShapeStyle(.primary))
                .background {
                    Capsule(style: .continuous)
                        .fill(isSelected ? style.iconBackground : style.iconRim)
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func renameField(for tab: FavoriteTab) -> some View {
        let style = SiriGlassStyle.resolve(for: colorScheme)
        return TextField("Group Name", text: $renameDraft)
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .focused($isRenameFocused)
            .padding(.horizontal, 10)
            .frame(width: 110, height: 26)
            .background(Capsule(style: .continuous).fill(style.iconBackground))
            .onSubmit { commitRename(tab) }
            .onExitCommand { cancelRename() }
            .onChange(of: isRenameFocused) { _, focused in
                // 点到别处就提交，不做隐式丢弃：用户已经输入的内容不应被静默吞掉。
                if !focused, renamingTabID == tab.id { commitRename(tab) }
            }
    }

    private var addButton: some View {
        Button {
            if let tab = create() { beginRenaming(tab) }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 26, height: 26)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(Text("New Group"))
        .accessibilityLabel(Text("New Group"))
    }

    private func beginRenaming(_ tab: FavoriteTab) {
        renameDraft = tab.name
        renamingTabID = tab.id
    }

    private func commitRename(_ tab: FavoriteTab) {
        guard renamingTabID == tab.id else { return }
        rename(tab, renameDraft)
        renamingTabID = nil
    }

    private func cancelRename() {
        renamingTabID = nil
    }
}

#Preview("Dark") {
    FavoriteTabBarPreview()
        .padding(24)
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    FavoriteTabBarPreview()
        .padding(24)
        .preferredColorScheme(.light)
}

private struct FavoriteTabBarPreview: View {
    @State private var model = ClipboardPanelModel.preview()
    @State private var renaming: UUID?
    @State private var draft = ""

    var body: some View {
        FavoriteTabBar(
            tabs: model.store.tabs,
            selectedTabID: model.selectedTabID,
            renamingTabID: $renaming,
            renameDraft: $draft,
            select: model.selectTab,
            create: model.createTab,
            rename: model.renameTab,
            delete: model.deleteTab
        )
            .frame(width: 392)
            .frame(width: 392)
    }
}
