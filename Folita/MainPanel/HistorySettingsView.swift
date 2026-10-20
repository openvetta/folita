import SwiftUI

/// 历史记录设置：保留条数、占用空间与清空。
struct HistorySettingsView: View {
    @Environment(HistorySettings.self) private var historySettings
    @Environment(ClipboardHistoryStore.self) private var store
    var storageDirectory: URL = HistoryStorage.defaultDirectory

    @State private var diskUsage: Int64 = 0
    @State private var isConfirmingClear = false

    var body: some View {
        @Bindable var settings = historySettings
        Form {
            Section {
                Picker("Keep", selection: $settings.limit) {
                    ForEach(HistorySettings.limitOptions, id: \.self) { limit in
                        Text("\(limit) items").tag(limit)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Retention")
            } footer: {
                Text("When the limit is reached, the oldest items are removed. Copies larger than 10 MB are not saved.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent {
                    Text(store.items.count, format: .number)
                } label: {
                    Text("Items Saved")
                }
                LabeledContent {
                    Text(diskUsage, format: .byteCount(style: .file))
                } label: {
                    Text("Storage Used")
                }
                Button("Clear History…", role: .destructive) {
                    isConfirmingClear = true
                }
                .disabled(store.items.isEmpty)
            } header: {
                Text("Storage")
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refreshDiskUsage)
        .onChange(of: store.items.count) { refreshDiskUsage() }
        .confirmationDialog("Clear all clipboard history?", isPresented: $isConfirmingClear) {
            Button("Clear History", role: .destructive) {
                store.clearAll()
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    private func refreshDiskUsage() {
        diskUsage = HistoryStorage.diskUsage(of: storageDirectory)
    }
}
