import Foundation

@MainActor
class GroupStore: ObservableObject {
    static let shared = GroupStore()
    
    @Published private(set) var groups: [PortfolioGroup] = []
    private let userDefaults = UserDefaults.standard
    private let key = "SavedGroups"
    
    private init() {
        load()
    }
    
    func list() -> [PortfolioGroup] {
        groups.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    @discardableResult
    func add(name: String) -> PortfolioGroup {
        let nextOrder = (groups.map { $0.sortOrder }.max() ?? -1) + 1
        let g = PortfolioGroup(name: name, sortOrder: nextOrder)
        groups.append(g)
        save()
        return g
    }
    
    func rename(id: String, name: String) {
        guard let idx = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[idx].name = name
        save()
    }
    
    func remove(id: String, portfolioViewModel: PortfolioViewModel) {
        groups.removeAll { $0.id == id }
        save()
        // 将该分组下的资产解绑
        portfolioViewModel.unassignGroup(for: id)
    }
    
    func reorder(idsInOrder: [String]) {
        var orderMap: [String: Int] = [:]
        for (i, id) in idsInOrder.enumerated() { orderMap[id] = i }
        for i in groups.indices {
            if let o = orderMap[groups[i].id] { groups[i].sortOrder = o }
        }
        save()
    }
    
    func replaceAll(_ newGroups: [PortfolioGroup]) {
        groups = newGroups
        save()
    }
    
    func merge(_ items: [PortfolioGroup]) {
        let existingIds = Set(groups.map { $0.id })
        var merged = groups
        for g in items where !existingIds.contains(g.id) { merged.append(g) }
        groups = merged
        save()
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(groups) {
            userDefaults.set(data, forKey: key)
        }
    }
    
    private func load() {
        if let data = userDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([PortfolioGroup].self, from: data) {
            groups = decoded
        }
    }
}


