import SwiftUI

struct MainPanelView: View {
    @Environment(ClipboardPanelController.self) private var clipboardPanel
    @State private var selection: MainSection?

    init(initialSection: MainSection = .general) {
        _selection = State(initialValue: initialSection)
    }

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
        case .favorites:
            FavoritesView()
        case .shortcuts:
            ShortcutsSettingsView()
        case .history:
            HistorySettingsView()
        case .privacy:
            PrivacySettingsView()
        case .about:
            AboutView()
        }
    }
}
