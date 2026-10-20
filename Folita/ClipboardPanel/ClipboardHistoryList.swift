import SwiftUI

/// 剪贴面板中的历史列表。
struct ClipboardHistoryList: View {
    @Bindable var model: ClipboardPanelModel

    var body: some View {
        let items = model.visibleItems
        if items.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(items) { item in
                            // 悬停只高亮不选中：选中会展开行，跟随鼠标会让列表在指针下来回跳动。
                            ClipboardHistoryRow(
                                item: item,
                                isSelected: item.id == model.selectedItem?.id,
                                targetAppName: model.targetAppName,
                                canAutoPaste: model.canAutoPaste
                            )
                                .id(item.id)
                                .onTapGesture {
                                    model.select(item)
                                    model.perform(.paste(.original))
                                }
                                .contextMenu { contextMenu(for: item) }
                        }
                    }
                    // 底部留出空间，最后几行不会落在容器的渐隐区里。
                    .padding(.bottom, 72)
                }
                .scrollIndicators(.never)
                .animation(.snappy(duration: 0.22), value: model.selectedItem?.id)
                .onChange(of: model.selectedItem?.id) { _, id in
                    guard let id else { return }
                    withAnimation(.snappy(duration: 0.22)) {
                        proxy.scrollTo(id)
                    }
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

/// 一条历史。未选中时只占一行；选中时就地展开成卡片，显示预览、来源与大小等信息和回填按键，
/// 让窄面板在保持简洁的同时，当前这条的内容都能看清。
struct ClipboardHistoryRow: View {
    let item: HistoryItem
    let isSelected: Bool
    var targetAppName: String?
    var canAutoPaste = false

    @State private var isHovering = false
    @State private var thumbnail: CGImage?

    var body: some View {
        Group {
            if isSelected {
                expanded
            } else {
                collapsed
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .onHover { isHovering = $0 }
        .task(id: TaskID(item: item.id, isSelected: isSelected)) {
            guard item.category == .image,
                  let data = item.clipContents.first(where: { ClipboardCapture.imageTypes.contains($0.type) })?.data
            else { return }
            thumbnail = await ClipPreviewImages.thumbnail(from: data, maxPixelSize: isSelected ? 720 : 64)
        }
    }

    private struct TaskID: Equatable {
        let item: UUID
        let isSelected: Bool
    }

    // MARK: 收起

    private var collapsed: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: 26, height: 26)
            titleText
                .font(.system(size: 14))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background {
            if isHovering {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.primary.opacity(0.06))
            }
        }
    }

    // MARK: 展开

    private var expanded: some View {
        let details = ClipDetails(contents: item.clipContents, category: item.category)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                icon
                    .frame(width: 26, height: 26)
                expandedTitle(details)
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
            }

            preview(details)

            metadata(details)

            keyHints
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.primary.opacity(0.10))
        }
    }

    @ViewBuilder
    private func preview(_ details: ClipDetails) -> some View {
        switch item.category {
        case .image:
            if let thumbnail {
                Image(decorative: thumbnail, scale: 2)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        case .file:
            VStack(alignment: .leading, spacing: 4) {
                ForEach(details.fileURLs.prefix(3), id: \.self) { url in
                    Text(verbatim: url.path(percentEncoded: false))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if details.fileURLs.count > 3 {
                    Text("and \(details.fileURLs.count - 3) more")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 12))
            .padding(.leading, 38)
        case .color:
            if let color = details.color {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.alpha))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(.primary.opacity(0.15))
                    }
                    .frame(height: 44)
            }
        case .text, .richText, .email, .link:
            // 文本类的完整内容已在标题位置展开。
            EmptyView()
        }
    }

    /// 文本类展开后直接显示多行正文；其他类别显示一行标题。
    @ViewBuilder
    private func expandedTitle(_ details: ClipDetails) -> some View {
        if item.category.isTextual, let text = details.text {
            Text(verbatim: text.trimmingCharacters(in: .whitespacesAndNewlines))
                .lineLimit(6)
                .truncationMode(.tail)
        } else {
            titleText
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    /// 来源 · 类型 · 尺寸/字数/文件数 · 大小 · 时间，一行看完。
    private func metadata(_ details: ClipDetails) -> some View {
        HStack(spacing: 6) {
            if let bundleID = item.sourceBundleID {
                if let appIcon = ClipPreviewImages.appIcon(bundleID: bundleID) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                }
                Text(verbatim: ClipPreviewImages.appName(bundleID: bundleID) ?? bundleID)
                separator
            }
            Text(item.category.title)
            if let size = details.pixelSize {
                separator
                Text(verbatim: "\(Int(size.width))×\(Int(size.height))")
            } else if details.fileURLs.count > 1 {
                separator
                Text("\(details.fileURLs.count) files")
            } else if let characters = details.characterCount, item.category.isTextual {
                separator
                Text("\(characters) characters")
            }
            separator
            Text(Int64(details.byteCount), format: .byteCount(style: .file))
            separator
            Text(item.lastCopiedAt, format: .relative(presentation: .named))
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.leading, 38)
    }

    private var separator: some View {
        Text(verbatim: "·").foregroundStyle(.tertiary)
    }

    private var keyHints: some View {
        HStack(spacing: 14) {
            KeyHint(keys: "↩") {
                if !canAutoPaste {
                    Text("Copy")
                } else if let targetAppName {
                    Text("Paste to \(targetAppName)")
                } else {
                    Text("Paste")
                }
            }
            if item.category.isTextual {
                KeyHint(keys: "⇧↩") { Text("Plain Text") }
            }
        }
        .padding(.leading, 38)
    }

    // MARK: 共用

    @ViewBuilder
    private var icon: some View {
        if let thumbnail, !isSelected || item.category != .image {
            Image(decorative: thumbnail, scale: 2)
                .resizable()
                .scaledToFill()
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: item.category.symbolName)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    /// 图片没有文本标题；文件只显示文件名。
    private var titleText: Text {
        switch item.category {
        case .image:
            Text("Image")
        case .file:
            Text(verbatim: item.title
                .split(separator: "\n")
                .map { URL(filePath: String($0)).lastPathComponent }
                .joined(separator: ", "))
        default:
            Text(verbatim: item.title.components(separatedBy: .newlines).first ?? item.title)
        }
    }
}

/// 按键提示：键帽 + 说明。
private struct KeyHint<Label: View>: View {
    let keys: String
    @ViewBuilder let label: Label

    var body: some View {
        HStack(spacing: 5) {
            Text(verbatim: keys)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .accessibilityHidden(true)
            label
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.secondary)
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
    var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .richText: "doc.richtext"
        case .image: "photo"
        case .file: "doc"
        case .link: "link"
        case .color: "paintpalette"
        case .email: "at"
        }
    }
}
