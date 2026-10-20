import SwiftUI

struct ClipboardPanelView: View {
    var onClose: () -> Void = {}

    @State private var filter: ClipboardFilter = .all
    @State private var isFilterPresented = false

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
    }

    /// 顶部可拖拽区域：按钮之间的空白与标题都可拖动面板，按钮自身保持点击。
    private var dragRegion: some View {
        VStack(alignment: .leading, spacing: 18) {
            topBar
            header
        }
        .contentShape(.rect)
        .gesture(WindowDragGesture())
    }

    /// 左侧关闭、右侧筛选，两端圆形控件，标题在其下方。
    private var topBar: some View {
        HStack(spacing: 0) {
            closeButton
            Spacer(minLength: 0)
            filterButton
        }
        .frame(height: 30)
    }

    /// 左上角关闭按钮，使用系统 Liquid Glass 按钮样式，位置对齐 macOS 窗口红绿灯。
    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .help(Text("Close"))
        .accessibilityLabel(Text("Close"))
    }

    private var filterButton: some View {
        Button {
            isFilterPresented.toggle()
        } label: {
            Image(systemName: filter.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .help(Text("Filter"))
        .accessibilityLabel(Text("Filter"))
        .popover(isPresented: $isFilterPresented, arrowEdge: .bottom) {
            ClipboardFilterMenu(selection: $filter)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Clipboard")
                .font(.system(size: 26, weight: .semibold))
            Text(filter == .all ? "Recent copies" : String(localized: filter.title))
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
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
