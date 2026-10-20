import SwiftUI

struct ClipboardPanelView: View {
    @Environment(LanguageSettings.self) private var languageSettings: LanguageSettings?
    @Bindable var model: ClipboardPanelModel

    @State private var isFilterPresented = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        SiriGlassContainer {
            VStack(alignment: .leading, spacing: 14) {
                dragRegion
                ClipboardHistoryList(model: model)
                    .frame(maxHeight: .infinity, alignment: .top)
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
        .onChange(of: model.presentationCount) {
            isSearchFocused = true
        }
        // 焦点始终在搜索框里，固定按键在此统一拦截，其余按键照常输入搜索词。
        .onKeyPress(phases: .down) { press in
            guard let command = ClipboardPanelCommand.command(for: press.key, modifiers: press.modifiers) else {
                return .ignored
            }
            model.perform(command)
            return .handled
        }
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
                ClipboardSearchField(query: $model.query, isFocused: $isSearchFocused)
            }
        }
        .frame(height: ClipboardPanelMetrics.controlHeight)
    }

    private var filterButton: some View {
        Button {
            isFilterPresented.toggle()
        } label: {
            Image(systemName: model.filter.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: ClipboardPanelMetrics.controlHeight, height: ClipboardPanelMetrics.controlHeight)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .help(Text("Filter"))
        .accessibilityLabel(Text("Filter"))
        .popover(isPresented: $isFilterPresented, arrowEdge: .bottom) {
            if let languageSettings {
                ClipboardFilterMenu(selection: $model.filter)
                    .environment(languageSettings)
                    .environment(\.locale, languageSettings.effectiveLocale)
            } else {
                ClipboardFilterMenu(selection: $model.filter)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Clipboard")
                .font(.system(size: 26, weight: .semibold))
            if model.filter == .all {
                Text("Recent copies")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            } else {
                Text(model.filter.title)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
    }
}

#Preview("Dark") {
    ClipboardPanelView(model: .preview())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    ClipboardPanelView(model: .preview())
        .preferredColorScheme(.light)
}

extension ClipboardPanelModel {
    /// 预览用的内存数据。
    static func preview() -> ClipboardPanelModel {
        let store = ClipboardHistoryStore(container: HistoryStorage.makeInMemoryContainer(), limit: { 500 })
        for text in ["Quarterly report draft", "#1E90FF", "https://folita.app", "hello@folita.app"] {
            store.record(CapturedClip(contents: [ClipContent(type: .string, data: Data(text.utf8))], sourceBundleID: nil))
        }
        return ClipboardPanelModel(store: store)
    }
}
