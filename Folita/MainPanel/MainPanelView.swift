import SwiftUI

struct MainPanelView: View {
    @Environment(ClipboardPanelController.self) private var clipboardPanel
    /// 主面板窗口打开期间在程序坞显示图标，关闭后恢复菜单栏应用。
    @Environment(DockIconVisibility.self) private var dockIcon: DockIconVisibility?
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
        // 主面板是唯一需要有程序坞图标的界面：打开时切回常规应用，关闭后回到菜单栏常驻。
        .onAppear { dockIcon?.mainPanelDidAppear() }
        .onDisappear { dockIcon?.mainPanelDidDisappear() }
    }

    @ViewBuilder
    private func detailView(for section: MainSection) -> some View {
        switch section {
        case .general:
            GeneralSettingsView()
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
