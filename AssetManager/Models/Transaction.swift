import Foundation

/// 交易类型
enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case buy
    case sell
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .buy: return "买入"
        case .sell: return "卖出"
        }
    }
}

/// 交易记录
struct Transaction: Identifiable, Codable {
    let id: UUID
    let stockCode: String
    let stockName: String
    let market: MarketType
    let currency: CurrencyType
    let type: TransactionType
    let shares: Double
    let price: Double
    let fees: Double
    let date: Date
    let note: String?
    
    // 卖出时的已实现盈亏（买入时为 nil）
    let realizedProfitLoss: Double?
    
    init(
        id: UUID = UUID(),
        stockCode: String,
        stockName: String,
        market: MarketType,
        currency: CurrencyType,
        type: TransactionType,
        shares: Double,
        price: Double,
        fees: Double = 0,
        date: Date = Date(),
        note: String? = nil,
        realizedProfitLoss: Double? = nil
    ) {
        self.id = id
        self.stockCode = stockCode
        self.stockName = stockName
        self.market = market
        self.currency = currency
        self.type = type
        self.shares = shares
        self.price = price
        self.fees = fees
        self.date = date
        self.note = note
        self.realizedProfitLoss = realizedProfitLoss
    }
    
    var amount: Double { shares * price }
}


