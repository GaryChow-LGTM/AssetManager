import Foundation

/// 简单的交易记录本地存储（UserDefaults）
@MainActor
class TransactionStore: ObservableObject {
    static let shared = TransactionStore()
    
    @Published private(set) var transactions: [Transaction] = []
    
    private let userDefaults = UserDefaults.standard
    private let key = "SavedTransactions"
    
    private init() {
        load()
    }
    
    func add(_ tx: Transaction) {
        transactions.append(tx)
        save()
    }
    
    func list(for stockCode: String, market: MarketType) -> Page<Transaction> {
        let items = transactions
            .filter { $0.stockCode == stockCode && $0.market == market }
            .sorted { $0.date > $1.date }
        return Page(items: items)
    }
    
    func listAll() -> [Transaction] { transactions }
    
    private func save() {
        if let data = try? JSONEncoder().encode(transactions) {
            userDefaults.set(data, forKey: key)
        }
    }
    
    private func load() {
        if let data = userDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Transaction].self, from: data) {
            transactions = decoded
        }
    }
}

/// 简易分页容器，后续可扩展分页
struct Page<T> {
    let items: [T]
}


