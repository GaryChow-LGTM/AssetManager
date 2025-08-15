import SwiftUI

struct GroupManagementView: View {
    @ObservedObject var viewModel: PortfolioViewModel
    @StateObject private var store = GroupStore.shared
    @State private var newGroupName: String = ""
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        List {
            // 教程/使用说明
            Section(header: Text("如何对持仓进行分组")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("1.")
                            .fontWeight(.semibold)
                        Text("先在此处新建分组（如：长期、波段、行业等）。")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("2.")
                            .fontWeight(.semibold)
                        Text("返回首页“我的持仓”，长按持仓行打开“菜单”，点击“移动到分组”，选择目标分组。")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("3.")
                            .fontWeight(.semibold)
                        Text("在首页顶部的分组标签中切换分组，仅查看该分组的持仓。默认“全部”展示所有持仓，“未分组”表示尚未分配分组的持仓。")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("4.")
                            .fontWeight(.semibold)
                        Text("删除分组不会删除持仓，分组内持仓会自动回到“未分组/全部”。")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            Section(header: Text("新建分组")) {
                HStack {
                    TextField("输入分组名称", text: $newGroupName)
                    Button("添加") {
                        addGroup()
                    }
                    .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            
            Section(header: Text("我的分组")) {
                ForEach(store.list(), id: \.id) { g in
                    HStack {
                        Text(g.name)
                        Spacer()
                        Menu("更多") {
                            Button("重命名") { promptRename(group: g) }
                            Button(role: .destructive) { store.remove(id: g.id, portfolioViewModel: viewModel) } label: { Text("删除") }
                        }
                    }
                }
                .onMove(perform: onMove)
            }
        }
        .navigationTitle("管理分组")
        #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { EditButton() }
        .environment(\.editMode, $editMode)
    }
    
    private func addGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        _ = store.add(name: name)
        newGroupName = ""
    }
    
    private func promptRename(group: PortfolioGroup) {
        // 简化：直接用一个临时 AlertSheet 方案可后续补充；此处先用控制台或占位
        // MVP：暂以快速重命名为例（追加后缀）
        store.rename(id: group.id, name: group.name + "(改)")
    }
    
    private func onMove(from: IndexSet, to: Int) {
        var ids = store.list().map { $0.id }
        ids.move(fromOffsets: from, toOffset: to)
        store.reorder(idsInOrder: ids)
    }
}


