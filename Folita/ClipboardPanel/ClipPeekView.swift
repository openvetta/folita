import AppKit
import SwiftUI

/// 详情预览（peek）时面板右侧的详情栏：与左侧列表同处一块玻璃，只靠分割线分栏，不再套卡片。
/// 上下切换条目时内容淡入淡出。
struct ClipPeekPanel: View {
    /// 当前选中的条目；搜索或筛选后列表为空时为 nil。
    let item: HistoryItem?
    /// 文件条目的「从访达打开」。
    var onOpenInFinder: (HistoryItem) -> Void = { _ in }

    var body: some View {
        ZStack {
            if let item {
                ClipPeekCard(item: item, onOpenInFinder: { onOpenInFinder(item) })
                    .id(item.id)
                    .transition(.opacity)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("Nothing to preview")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.16), value: item?.id)
    }
}

/// 两栏之间的竖向分割线，两端渐隐，不在顶栏和底部把手处生硬截断。
struct ClipPeekDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let color = SiriGlassStyle.resolve(for: colorScheme).peekDivider
        Rectangle()
            .fill(LinearGradient(
                stops: [
                    .init(color: color.opacity(0), location: 0),
                    .init(color: color, location: 0.08),
                    .init(color: color, location: 0.85),
                    .init(color: color.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            ))
            .frame(width: 1)
            .accessibilityHidden(true)
    }
}

/// 详情栏的内容：上半部分是大图或正文，下半部分是信息列表。
struct ClipPeekCard: View {
    let item: HistoryItem
    var onOpenInFinder: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme
    @State private var image: CGImage?

    var body: some View {
        let details = ClipDetails(contents: item.clipContents, category: item.category)
        let style = SiriGlassStyle.resolve(for: colorScheme)

        VStack(alignment: .leading, spacing: 14) {
            preview(details, style: style)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            information(details, style: style)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Preview"))
        .task(id: item.id) {
            guard item.category == .image,
                  let data = item.clipContents.first(where: { ClipboardCapture.imageTypes.contains($0.type) })?.data
            else { return }
            image = await ClipPreviewImages.thumbnail(from: data, maxPixelSize: 1200)
        }
    }

    // MARK: 预览

    @ViewBuilder
    private func preview(_ details: ClipDetails, style: SiriGlassStyle) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        switch item.category {
        case .image:
            ZStack {
                if let image {
                    Image(decorative: image, scale: 2)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: style.peekShadow, radius: 8, y: 3)
                        .padding(12)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(style.peekWell, in: shape)
        case .color:
            if let color = details.color {
                shape
                    .fill(Color(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.alpha))
                    .overlay { shape.strokeBorder(style.iconRim, lineWidth: 1) }
                    .overlay(alignment: .bottomLeading) {
                        Text(verbatim: details.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? item.title)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .glassEffect(.regular, in: .capsule)
                            .padding(12)
                    }
            } else {
                textPreview(details, style: style)
            }
        case .file:
            filePreview(details)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(style.peekWell, in: shape)
        case .link:
            linkPreview(details, style: style)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(style.peekWell, in: shape)
        case .text, .richText, .email:
            textPreview(details, style: style)
        }
    }

    private func textPreview(_ details: ClipDetails, style: SiriGlassStyle) -> some View {
        ScrollView {
            Text(verbatim: Self.previewText(details.text ?? item.title))
                .font(.system(size: 13))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
        .scrollIndicators(.automatic)
        .background(style.peekWell, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func linkPreview(_ details: ClipDetails, style: SiriGlassStyle) -> some View {
        let text = details.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? item.title
        return VStack(spacing: 10) {
            Image(systemName: ClipCategory.link.symbolName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(style.iconForeground)
                .frame(width: 52, height: 52)
                .background(style.iconBackground, in: .circle)
            if let host = details.link?.host() {
                Text(verbatim: host)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
            }
            Text(verbatim: text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .truncationMode(.middle)
        }
        .padding(20)
    }

    @ViewBuilder
    private func filePreview(_ details: ClipDetails) -> some View {
        if let first = details.fileURLs.first {
            VStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: first.path(percentEncoded: false)))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .accessibilityHidden(true)
                Text(verbatim: ClipboardHistoryRow.title(of: item))
                    .font(.system(size: 15, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text(verbatim: first.deletingLastPathComponent().path(percentEncoded: false))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button(action: onOpenInFinder) {
                    Label("Open in Finder", systemImage: "folder")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.glass)
                .padding(.top, 4)
            }
            .padding(20)
        } else {
            Image(systemName: ClipCategory.file.symbolName)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: 信息

    private func information(_ details: ClipDetails, style: SiriGlassStyle) -> some View {
        let fields = ClipPeekField.fields(for: item, details: details)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Information")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
            VStack(spacing: 0) {
                ForEach(Array(fields.enumerated()), id: \.offset) { index, field in
                    HStack(spacing: 12) {
                        Text(field.label)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        value(of: field)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    // 隔行衬底，长列表也能横向对齐着读。
                    .background(
                        index.isMultiple(of: 2) ? style.peekStripe : .clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    @ViewBuilder
    private func value(of field: ClipPeekField) -> some View {
        switch field {
        case .source(let bundleID):
            HStack(spacing: 6) {
                if let icon = ClipPreviewImages.appIcon(bundleID: bundleID) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                }
                Text(verbatim: ClipPreviewImages.appName(bundleID: bundleID) ?? bundleID)
            }
        case .type(let category):
            Text(category.title)
        case .dimensions(let size):
            Text(verbatim: "\(Int(size.width)) × \(Int(size.height))")
        case .characters(let count), .files(let count):
            Text(count, format: .number)
        case .size(let bytes):
            Text(Int64(bytes), format: .byteCount(style: .file))
        case .copied(let date):
            Text(date, format: .relative(presentation: .named))
        }
    }

    /// 超长文本只排版开头一段：预览是快速查看，整段排版会拖慢展开动画。
    static func previewText(_ text: String, limit: Int = 5000) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "…"
    }
}

/// 详情栏信息区的一行。
enum ClipPeekField: Equatable {
    case source(bundleID: String)
    case type(ClipCategory)
    case dimensions(CGSize)
    case characters(Int)
    case files(Int)
    case size(Int)
    case copied(Date)

    var label: LocalizedStringResource {
        switch self {
        case .source: "Source"
        case .type: "Type"
        case .dimensions: "Dimensions"
        case .characters: "Characters"
        case .files: "Files"
        case .size: "Size"
        case .copied: "Copied"
        }
    }

    /// 来源 → 类型 → 尺寸 / 文件数 / 字数 → 大小 → 复制时间；只列出这条记录真正具备的信息。
    static func fields(for item: HistoryItem, details: ClipDetails) -> [ClipPeekField] {
        var fields: [ClipPeekField] = []
        if let bundleID = item.sourceBundleID {
            fields.append(.source(bundleID: bundleID))
        }
        fields.append(.type(item.category))
        if let pixelSize = details.pixelSize {
            fields.append(.dimensions(pixelSize))
        }
        if !details.fileURLs.isEmpty {
            fields.append(.files(details.fileURLs.count))
        } else if item.category.isTextual, let characters = details.characterCount {
            fields.append(.characters(characters))
        }
        fields.append(.size(details.byteCount))
        fields.append(.copied(item.lastCopiedAt))
        return fields
    }
}
