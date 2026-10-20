import SwiftUI

struct ClipboardPanelView: View {
    @Environment(LanguageSettings.self) private var languageSettings: LanguageSettings?

    @State private var filter: ClipboardFilter = .all
    @State private var query = ""
    @State private var isFilterPresented = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        SiriGlassContainer {
            VStack(alignment: .leading, spacing: 18) {
                dragRegion
                ClipboardHistoryEmptyView(filter: filter)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(
            width: ClipboardPanelMetrics.containerSize.width,
            height: ClipboardPanelMetrics.containerSize.height
        )
        .shadow(color: .black.opacity(0.28), radius: 22, y: 10)
        .padding(ClipboardPanelMetrics.shadowInset)
        .defaultFocus($isSearchFocused, true)
    }

    /// 顶部可拖拽区域：控件之间的空白与标题都可拖动面板，控件自身保持交互。
    private var dragRegion: some View {
        VStack(alignment: .leading, spacing: 18) {
            topBar
            header
        }
        .contentShape(.rect)
        .gesture(WindowDragGesture())
    }

    /// 左侧筛选、右侧搜索。面板靠点击外部或 Esc 收起，不需要关闭按钮。
    /// 两个控件放进同一个 GlassEffectContainer，让液态玻璃在相邻时统一取样与融合。
    private var topBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                filterButton
                Spacer(minLength: 0)
                ClipboardSearchField(query: $query, isFocused: $isSearchFocused)
            }
        }
        .frame(height: ClipboardPanelMetrics.controlHeight)
    }

    private var filterButton: some View {
        Button {
            isFilterPresented.toggle()
        } label: {
            Image(systemName: filter.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: ClipboardPanelMetrics.controlHeight, height: ClipboardPanelMetrics.controlHeight)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .help(Text("Filter"))
        .accessibilityLabel(Text("Filter"))
        .popover(isPresented: $isFilterPresented, arrowEdge: .bottom) {
            if let languageSettings {
                ClipboardFilterMenu(selection: $filter)
                    .environment(languageSettings)
                    .environment(\.locale, languageSettings.effectiveLocale)
            } else {
                ClipboardFilterMenu(selection: $filter)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Clipboard")
                .font(.system(size: 26, weight: .semibold))
            if filter == .all {
                Text("Recent copies")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            } else {
                Text(filter.title)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
    }
}
/// 历史列表的占位；接入剪贴板监听后替换为真实列表。
struct ClipboardHistoryEmptyView: View {
    let filter: ClipboardFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: filter.symbolName)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.secondary)
            Text("Nothing here yet")
                .font(.system(size: 20, weight: .medium))
            Text(description)
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 16)
        .padding(.horizontal, 6)
    }

    private var description: LocalizedStringResource {
        filter == .all
            ? "Copied text, images and files will appear here."
            : "No items of this type yet."
    }
}

#Preview("Dark") {
    ClipboardPanelView()
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    ClipboardPanelView()
        .preferredColorScheme(.light)
}
