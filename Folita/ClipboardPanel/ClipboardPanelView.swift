import AppKit
import SwiftUI

struct ClipboardPanelView: View {
    @Environment(LanguageSettings.self) private var languageSettings: LanguageSettings?
    @Bindable var model: ClipboardPanelModel

    @State private var isFilterPresented = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        let isPeeking = model.isPeeking
        let container = ClipboardPanelMetrics.containerSize(isPeeking: isPeeking)

        SiriGlassContainer {
            VStack(alignment: .leading, spacing: 18) {
                // 顶栏与标题都可拖动面板，控件自身保持交互。
                topBar
                    .contentShape(.rect)
                    .gesture(WindowDragGesture())
                VStack(alignment: .leading, spacing: 14) {
                    header
                        .contentShape(.rect)
                        .gesture(WindowDragGesture())
                    PanelNoticeBanner(notice: model.notice, action: model.resolveNotice, onDismiss: model.dismissNotice)
                    ClipboardHistoryList(model: model)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                // 预览时列表收窄到左侧 1/3，右侧 2/3 留给详情栏。
                .frame(width: ClipboardPanelMetrics.listColumnWidth(isPeeking: isPeeking), alignment: .leading)
            }
            .padding(.horizontal, ClipboardPanelMetrics.contentInset)
            .padding(.top, ClipboardPanelMetrics.contentTopInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: container.width, height: container.height)
        // 详情栏画在玻璃容器的内容蒙版之外：容器底部的渐隐会吃掉详情下半部分的信息区。
        .overlay(alignment: .topLeading) {
            if isPeeking {
                let detail = ClipboardPanelMetrics.peekDetailFrame(in: container)
                ZStack(alignment: .topLeading) {
                    ClipPeekDivider()
                        .frame(height: detail.height)
                        .offset(x: ClipboardPanelMetrics.peekDividerX(in: container), y: detail.minY)
                    ClipPeekPanel(item: model.selectedItem)
                        .frame(width: detail.width, height: detail.height)
                        .offset(x: detail.minX, y: detail.minY)
                }
                .transition(.opacity.combined(with: .offset(x: 20)))
            }
        }
        .animation(.snappy(duration: ClipboardPanelMetrics.peekAnimationDuration), value: isPeeking)
        .shadow(color: .black.opacity(0.28), radius: 22, y: 10)
        .padding(ClipboardPanelMetrics.shadowInset)
        .defaultFocus($isSearchFocused, true)
        .onChange(of: model.presentationCount) {
            isSearchFocused = true
        }
        // 从系统设置授权后切回来，提示应立即消失。
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshNotice()
        }
        // 固定按键由 ClipboardPanelController 在窗口分发前拦截：搜索框聚焦时
        // TextField 会先消费方向键，视图层的 onKeyPress 收不到这些按键。
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
