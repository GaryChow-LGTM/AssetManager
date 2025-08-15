import Foundation

@MainActor
class AssetDetailViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var filterType: TransactionType? = nil
    @Published var timeRange: TimeRangeFilter = .all
    
    let stockCode: String
    let market: MarketType
    let currency: CurrencyType
    
    private let store = TransactionStore.shared
    
    init(stockCode: String, market: MarketType, currency: CurrencyType) {
        self.stockCode = stockCode
        self.market = market
        self.currency = currency
        load()
    }
    
    func load() {
        let page = store.list(for: stockCode, market: market)
        var items = page.items
        if let type = filterType {
            items = items.filter { $0.type == type }
        }
        let (start, end) = timeRange.dateBounds()
        if let start = start { items = items.filter { $0.date >= start } }
        if let end = end { items = items.filter { $0.date <= end } }
        transactions = items
    }
    
    // 摘要
    var totalBuyAmount: Double {
        transactions.filter { $0.type == .buy }.reduce(0) { $0 + $1.amount + $1.fees }
    }
    var totalSellAmount: Double {
        transactions.filter { $0.type == .sell }.reduce(0) { $0 + $1.amount - $1.fees }
    }
    var totalRealizedPL: Double {
        transactions.compactMap { $0.realizedProfitLoss }.reduce(0, +)
    }
}

enum TimeRangeFilter: String, CaseIterable, Identifiable {
    case month1
    case month3
    case year1
    case all
    
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .month1: return "近1月"
        case .month3: return "近3月"
        case .year1: return "近1年"
        case .all: return "全部"
        }
    }
    
    func dateBounds() -> (Date?, Date?) {
        let now = Date()
        let cal = Calendar.current
        switch self {
        case .month1:
            return (cal.date(byAdding: .month, value: -1, to: now), now)
        case .month3:
            return (cal.date(byAdding: .month, value: -3, to: now), now)
        case .year1:
            return (cal.date(byAdding: .year, value: -1, to: now), now)
        case .all:
            return (nil, nil)
        }
    }
}


