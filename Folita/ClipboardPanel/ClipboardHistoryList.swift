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
                    LazyVStack(spacing: 2) {
                        ForEach(items) { item in
                            ClipboardHistoryRow(item: item, isSelected: item.id == model.selectedItem?.id)
                                .id(item.id)
                                .onHover { hovering in
                                    if hovering { model.select(item) }
                                }
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
                .onChange(of: model.selectedItem?.id) { _, id in
                    guard let id else { return }
                    proxy.scrollTo(id)
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

struct ClipboardHistoryRow: View {
    let item: HistoryItem
    let isSelected: Bool

    @State private var thumbnail: CGImage?

    var body: some View {
        HStack(spacing: 12) {
            leading
                .frame(width: 32, height: 32)

            titleText
                .font(.system(size: 14))
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                if let bundleID = item.sourceBundleID, let icon = ClipPreviewImages.appIcon(bundleID: bundleID) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                }
                Text(item.lastCopiedAt, format: .relative(presentation: .named))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.primary.opacity(0.12))
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .task(id: item.id) {
            guard item.category == .image,
                  let data = item.clipContents.first(where: { ClipboardCapture.imageTypes.contains($0.type) })?.data
            else { return }
            thumbnail = await ClipPreviewImages.thumbnail(from: data, maxPixelSize: 96)
        }
    }

    @ViewBuilder
    private var leading: some View {
        if let thumbnail {
            Image(decorative: thumbnail, scale: 2)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: item.category.symbolName)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            Text(verbatim: item.title)
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
