import SwiftUI

struct MainPanelView: View {
    @Environment(ClipboardPanelController.self) private var clipboardPanel
    @State private var selection: MainSection? = .general

    private var currentSection: MainSection { selection ?? .general }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(MainSection.allCases) { section in
                    Label {
                        Text(section.title)
                    } icon: {
                        Image(systemName: section.symbolName)
                    }
                    .tag(section)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            detailView(for: currentSection)
                .navigationTitle(Text(currentSection.title))
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    clipboardPanel.toggle()
                } label: {
                    Label("Show Clipboard Panel", systemImage: "rectangle.on.rectangle")
                }
                .help(Text("Show Clipboard Panel"))
            }
        }
        .frame(minWidth: 680, minHeight: 440)
    }

    @ViewBuilder
    private func detailView(for section: MainSection) -> some View {
        switch section {
        case .general:
            GeneralSettingsView()
        default:
            SectionPlaceholderView(section: section)
        }
    }
}

/// 各设置页的占位视图；功能落地后替换为对应的 Form。
struct SectionPlaceholderView: View {
    let section: MainSection

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(section.title)
            } icon: {
                Image(systemName: section.symbolName)
            }
        } description: {
            Text("This section is not implemented yet.")
        }
    }
}
