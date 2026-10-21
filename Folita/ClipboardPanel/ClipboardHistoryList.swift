import SwiftUI

/// 剪贴面板中的历史列表。
struct ClipboardHistoryList: View {
    @Bindable var model: ClipboardPanelModel
    @State private var scrollPosition = ScrollPosition(idType: Never.self)
    @State private var listGeometry = ListGeometry()


    var body: some View {
        let items = model.visibleItems
        if items.isEmpty {
            emptyState
        } else {
            let selectedID = model.selectedItem?.id
            ScrollView {
                LazyVStack(spacing: ClipboardPanelMetrics.historyRowSpacing) {
                    ForEach(items) { item in
                        // 悬停只高亮不选中：跟随鼠标改变选中项会让列表在指针下来回跳动。
                        ClipboardHistoryRow(item: item, isSelected: item.id == selectedID, isCompact: model.isPeeking)
                            .id(item.id)
                            .onTapGesture {
                                model.select(item)
                                model.perform(.paste(.original))
                            }
                            .contextMenu { contextMenu(for: item) }
                    }
                }
            }
            // 容器的渐隐区不能动，改为给滚动内容留出等高的底部空间：
            // 滚轮可以把最后几行推到渐隐区上方，方向键滚动时选中行也不会落在淡出区域。
            .contentMargins(.bottom, ClipboardPanelMetrics.listBottomSafeSpace, for: .scrollContent)
            .scrollIndicators(.never)
            .scrollPosition($scrollPosition)
            .onScrollGeometryChange(for: ListGeometry.self) { geometry in
                ListGeometry(offset: geometry.contentOffset.y, viewportHeight: geometry.containerSize.height)
            } action: { _, geometry in
                listGeometry = geometry
            }
            .onChange(of: selectedID) { _, id in
                guard let id, let index = items.firstIndex(where: { $0.id == id }) else { return }
                let target = ClipboardHistoryScroll.targetOffset(
                    selectedIndex: index,
                    itemCount: items.count,
                    viewportHeight: listGeometry.viewportHeight,
                    currentOffset: listGeometry.offset
                )
                guard target != listGeometry.offset else { return }
                withAnimation(.snappy(duration: 0.22)) {
                    scrollPosition.scrollTo(y: target)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.store.items.isEmpty {
            ClipboardHistoryEmptyView(
                symbolName: ClipboardFilter.all.symbolName,
                title: "Nothing here yet",
                message: "Copied text, images and files will appear here."
            )
        } else if !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ClipboardHistoryEmptyView(
                symbolName: "magnifyingglass",
                title: "No matches",
                message: "Try a different search or filter."
            )
        } else {
            ClipboardHistoryEmptyView(
                symbolName: model.filter.symbolName,
                title: "Nothing here yet",
                message: "No items of this type yet."
            )
        }
    }

    @ViewBuilder
    private func contextMenu(for item: HistoryItem) -> some View {
        Button("Paste") {
            model.select(item)
            model.perform(.paste(.original))
        }
        Button("Paste as Plain Text") {
            model.select(item)
            model.perform(.paste(.plainText))
        }
        .disabled(!item.category.isTextual)
        Divider()
        Button("Delete", role: .destructive) {
            model.select(item)
            model.perform(.deleteSelected)
        }
    }
}

/// 一条历史：左侧是缩略图或类型图标，右侧两行——标题与元信息。所有行同高，选中只换底色，
/// 列表不会因为展开在指针下跳动，一屏也能稳定扫读。按键提示统一放在设置里的快捷键页。
struct ClipboardHistoryRow: View {
    let item: HistoryItem
    let isSelected: Bool
    /// 详情预览时列表收窄到 1/3：元信息只留类型与时间，其余都在右侧详情里，避免整行被截成省略号。
    var isCompact = false

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @State private var thumbnail: CGImage?

    var body: some View {
        let details = ClipDetails(contents: item.clipContents, category: item.category)
        HStack(spacing: 12) {
            icon(details)
            VStack(alignment: .leading, spacing: 2) {
                title(details)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                metadata(details)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .frame(height: ClipboardPanelMetrics.historyRowHeight)
        .background { background }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .onHover { isHovering = $0 }
        .task(id: item.id) {
            guard item.category == .image,
                  let data = item.clipContents.first(where: { ClipboardCapture.imageTypes.contains($0.type) })?.data
            else { return }
            thumbnail = await ClipPreviewImages.thumbnail(from: data, maxPixelSize: 64)
        }
    }

    // MARK: 背景

    private var background: some View {
        let style = SiriGlassStyle.resolve(for: colorScheme)
        let shape = RoundedRectangle(cornerRadius: ClipboardPanelMetrics.historyRowCornerRadius, style: .continuous)
        return shape
            .fill(rowFill(style))
            .overlay {
                if isSelected {
                    shape.strokeBorder(style.selectionRim, lineWidth: 1)
                }
            }
    }

    /// 选中时近乎实心，滚到容器下部的渐隐区也不会透出桌面；悬停只加一层很淡的着色。
    private func rowFill(_ style: SiriGlassStyle) -> Color {
        if isSelected { return style.selection }
        return isHovering ? .primary.opacity(0.06) : .clear
    }

    // MARK: 左侧

    /// 左侧图标块：图片用缩略图，颜色值用色块，其余用实心类型图标。尺寸与裁剪都在内部完成，
    /// 宽图按填充裁切，不会溢出到右侧文字上。
    @ViewBuilder
    private func icon(_ details: ClipDetails) -> some View {
        let style = SiriGlassStyle.resolve(for: colorScheme)
        let size = ClipboardPanelMetrics.historyIconSize
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)

        Group {
            if let thumbnail {
                Image(decorative: thumbnail, scale: 2)
                    .resizable()
                    .scaledToFill()
            } else if item.category == .color, let color = details.color {
                Rectangle()
                    .fill(Color(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.alpha))
            } else {
                Image(systemName: item.category.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(style.iconForeground)
            }
        }
        .frame(width: size, height: size)
        .background(style.iconBackground, in: shape)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(style.iconRim, lineWidth: 1)
        }
    }

    // MARK: 右侧

    @ViewBuilder
    private func title(_ details: ClipDetails) -> some View {
        if item.category == .image {
            Text(Self.imageTitle(pixelSize: details.pixelSize))
        } else {
            Text(verbatim: Self.title(of: item))
        }
    }

    /// 来源 · 类型 · 字数/文件数 · 大小 · 时间，一行看完；图片的尺寸已在标题里。
    private func metadata(_ details: ClipDetails) -> some View {
        HStack(spacing: 5) {
            if isCompact {
                if item.category != .image {
                    Text(item.category.title)
                    separator
                }
            } else {
                fullMetadata(details)
            }
            Text(item.lastCopiedAt, format: .relative(presentation: .named))
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    @ViewBuilder
    private func fullMetadata(_ details: ClipDetails) -> some View {
        if let bundleID = item.sourceBundleID {
            if let appIcon = ClipPreviewImages.appIcon(bundleID: bundleID) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)
            }
            Text(verbatim: ClipPreviewImages.appName(bundleID: bundleID) ?? bundleID)
            separator
        }
        // 图片的尺寸已经在标题里，元信息不再重复类型与尺寸。
        if item.category != .image {
            Text(item.category.title)
            separator
            if details.fileURLs.count > 1 {
                Text("\(details.fileURLs.count) files")
                separator
            } else if let characters = details.characterCount, item.category.isTextual {
                Text("\(characters) characters")
                separator
            }
        }
        Text(Int64(details.byteCount), format: .byteCount(style: .file))
        separator
    }

    private var separator: some View {
        Text(verbatim: "·").foregroundStyle(.tertiary)
    }

    // MARK: 标题

    /// 图片没有文本标题，改用像素尺寸；尺寸读不出来时只显示类型。
    /// 像素值转成字符串再插值，避免数字插值按本地化规则加上千位分隔符。
    static func imageTitle(pixelSize: CGSize?) -> LocalizedStringResource {
        guard let pixelSize else { return "Image" }
        let width = String(Int(pixelSize.width))
        let height = String(Int(pixelSize.height))
        return "Image (\(width) × \(height) px)"
    }

    /// 文件只显示文件名，其余取标题的第一行。
    static func title(of item: HistoryItem) -> String {
        switch item.category {
        case .file:
            item.title
                .split(separator: "\n")
                .map { URL(filePath: String($0)).lastPathComponent }
                .joined(separator: ", ")
        default:
            item.title.components(separatedBy: .newlines).first ?? item.title
        }
    }
}

extension ClipCategory {
    var title: LocalizedStringResource {
        switch self {
        case .text: "Text"
        case .richText: "Rich Text"
        case .image: "Image"
        case .file: "File"
        case .link: "Link"
        case .color: "Color"
        case .email: "Email"
        }
    }
}

struct ClipboardHistoryEmptyView: View {
    let symbolName: String
    let title: LocalizedStringResource
    let message: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 20, weight: .medium))
            Text(message)
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 16)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension ClipCategory {
    /// 避免使用 `textformat` 等会随语言本地化成文字字形的符号（中文下会显示为「格式」）。
    /// 有实心变体的类别用 `.fill`，与 iOS 的实心图标观感一致；文本、链接、邮箱没有实心变体，保留线性字形。
    var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .richText: "doc.richtext.fill"
        case .image: "photo.fill"
        case .file: "doc.fill"
        case .link: "link"
        case .color: "paintpalette.fill"
        case .email: "at"
        }
    }
}
