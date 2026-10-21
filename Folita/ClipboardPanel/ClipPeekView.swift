import AppKit
import SwiftUI

/// 详情预览（peek）时面板右侧的详情栏：与左侧列表同处一块玻璃，只靠分割线分栏，不再套卡片。
/// 上下切换条目时内容淡入淡出。
struct ClipPeekPanel: View {
    /// 当前选中的条目；搜索或筛选后列表为空时为 nil。
    let item: HistoryItem?
    /// 文件条目的「从访达打开」。
    var onOpenInFinder: (HistoryItem) -> Void = { _ in }
    /// 链接条目的「浏览器打开」。
    var onOpenInBrowser: (HistoryItem) -> Void = { _ in }
    /// 给某个邮件地址写信。
    var onComposeEmail: (String) -> Void = { _ in }
    /// 颜色条目转换成另一种格式并粘贴。
    var onConvertColor: (HistoryItem, ColorFormat) -> Void = { _, _ in }

    var body: some View {
        ZStack {
            if let item {
                ClipPeekCard(
                    item: item,
                    onOpenInFinder: { onOpenInFinder(item) },
                    onOpenInBrowser: { onOpenInBrowser(item) },
                    onComposeEmail: onComposeEmail,
                    onConvertColor: { onConvertColor(item, $0) }
                )
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
    var onOpenInBrowser: () -> Void = {}
    var onComposeEmail: (String) -> Void = { _ in }
    var onConvertColor: (ColorFormat) -> Void = { _ in }

    @Environment(\.colorScheme) private var colorScheme
    @State private var image: CGImage?

    var body: some View {
        let details = ClipDetails(contents: item.clipContents, category: item.category)
        let style = SiriGlassStyle.resolve(for: colorScheme)

        VStack(alignment: .leading, spacing: 14) {
            preview(details, style: style)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    actionButtons(details).padding(10)
                }
            information(details, style: style)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Preview"))
        .task(id: item.id) {
            image = await ClipPreviewImages.thumbnail(for: item, maxPixelSize: 1200)
        }
    }

    /// 右上角按钮占据的高度（按钮 + 上边距），文字预览据此下移。
    static let actionButtonsInset: CGFloat = 52

    /// 预览区右上角是否有操作按钮。
    static func hasActionButtons(_ details: ClipDetails) -> Bool {
        details.category == .file || details.link != nil || !details.emails.isEmpty || details.color != nil
    }

    /// 预览区右上角的操作按钮：文件 → 访达；链接 → 浏览器；含邮箱 → 发送邮件；颜色 → 转换格式。
    @ViewBuilder
    private func actionButtons(_ details: ClipDetails) -> some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                if item.category == .file {
                    openInFinderButton
                }
                if details.link != nil {
                    capsuleButton("Open in Browser", systemImage: "safari", action: onOpenInBrowser)
                }
                if details.emails.count == 1, let address = details.emails.first {
                    capsuleButton("Send Email", systemImage: "envelope") { onComposeEmail(address) }
                } else if details.emails.count > 1 {
                    Menu {
                        ForEach(details.emails, id: \.self) { address in
                            Button { onComposeEmail(address) } label: { Text(verbatim: address) }
                        }
                    } label: {
                        capsuleLabel("Send Email", systemImage: "envelope")
                    }
                    .menuStyle(.button)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .menuIndicator(.hidden)
                }
                if let color = details.color {
                    Menu {
                        // 菜单项直接写出转换后的色值，选中即复制。
                        ForEach(ColorFormat.allCases.filter { $0 != details.colorFormat }, id: \.self) { format in
                            Button { onConvertColor(format) } label: { Text(verbatim: format.string(for: color)) }
                        }
                    } label: {
                        capsuleLabel("Convert Color", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .menuStyle(.button)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .menuIndicator(.hidden)
                }
            }
        }
    }

    private func capsuleButton(_ title: LocalizedStringResource, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { capsuleLabel(title, systemImage: systemImage) }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
    }

    private func capsuleLabel(_ title: LocalizedStringResource, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 12, weight: .medium))
        }
    }

    /// 预览区右上角的胶囊按钮，左侧带访达图标。
    private var openInFinderButton: some View {
        Button(action: onOpenInFinder) {
            HStack(spacing: 6) {
                if let finderIcon = ClipPreviewImages.appIcon(bundleID: "com.apple.finder") {
                    Image(nsImage: finderIcon)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                }
                Text("Open in Finder")
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
    }

    // MARK: 预览

    /// 图片（含图片文件）的大图；解码完成前显示加载指示。
    private func imagePreview(style: SiriGlassStyle, shape: RoundedRectangle) -> some View {
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
    }

    @ViewBuilder
    private func preview(_ details: ClipDetails, style: SiriGlassStyle) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        switch item.category {
        case .image:
            imagePreview(style: style, shape: shape)
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
            // 图片文件显示图片本身，其余文件显示图标与路径。
            if image != nil {
                imagePreview(style: style, shape: shape)
            } else {
                filePreview(details)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(style.peekWell, in: shape)
            }
        case .link:
            if let target = details.linkTarget, let url = details.link {
                LinkBrandCard(target: target, url: url)
            } else {
                linkPreview(details, style: style)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(style.peekWell, in: shape)
            }
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
                .padding([.horizontal, .bottom], 14)
                // 右上角有操作按钮时文字从按钮下方开始，不被按钮盖住。
                .padding(.top, Self.hasActionButtons(details) ? Self.actionButtonsInset : 14)
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
