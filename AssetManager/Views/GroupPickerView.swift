import SwiftUI

struct GroupPickerView: View {
    let asset: Asset
    let onPicked: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = GroupStore.shared
    @State private var selectedIds: Set<String> = []
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("选择分组")) {
                    Button(action: { selectedIds.removeAll() }) {
                        HStack {
                            Text("未分组")
                            Spacer()
                            if selectedIds.isEmpty { Image(systemName: "checkmark") }
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 16)
                        .contentShape(Rectangle())
                    }
                    .listRowInsets(EdgeInsets())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    
                    ForEach(store.list(), id: \.id) { g in
                        Button(action: {
                            if selectedIds.contains(g.id) {
                                selectedIds.remove(g.id)
                            } else {
                                selectedIds.insert(g.id)
                            }
                        }) {
                            HStack {
                                Text(g.name)
                                Spacer()
                                if selectedIds.contains(g.id) { Image(systemName: "checkmark") }
                            }
                            .padding(.leading, 16)
                            .padding(.trailing, 16)
                            .contentShape(Rectangle())
                        }
                        .listRowInsets(EdgeInsets())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                    }
                }
                
                Section {
                    NavigationLink(destination: GroupManagementView(viewModel: PortfolioViewModel())) {
                        Label("管理分组", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .navigationTitle("\(asset.stockName) \(asset.stockCode)")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onPicked(Array(selectedIds))
                        dismiss()
                    }
                }
            }
            .onAppear { selectedIds = Set(asset.groupIds) }
        }
    }
}



