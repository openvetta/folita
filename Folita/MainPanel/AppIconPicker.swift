import SwiftUI

/// 通用设置中的应用图标网格，点选即生效。
struct AppIconPicker: View {
    @Environment(AppIconSettings.self) private var settings

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(AppIconOption.allCases) { option in
                AppIconCell(option: option, isSelected: settings.selection == option) {
                    settings.selection = option
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AppIconCell: View {
    let option: AppIconOption
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: 6) {
                Group {
                    if let image = option.image {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                    } else {
                        Image(systemName: "app.dashed")
                            .resizable()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 48, height: 48)
                .padding(3)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 2.5)
                        .opacity(isSelected ? 1 : 0)
                }
                Text(option.title)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(option.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
