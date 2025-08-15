import Foundation

/// 资产数据模型
struct Asset: Identifiable, Codable, Hashable {
    let id = UUID()
    let stockCode: String // 股票代码
    let stockName: String // 股票名称
    let market: MarketType // 所属市场
    var shares: Double // 持股数量
    var costPrice: Double // 平均成本价
    var currentPrice: Double // 当前价格
    let addedDate: Date // 添加日期
    
    /// 当前市值
    var currentValue: Double {
        shares * currentPrice
    }
    
    /// 总成本
    var totalCost: Double {
        shares * costPrice
    }
    
    /// 盈亏金额
    var profitLoss: Double {
        currentValue - totalCost
    }
    
    /// 盈亏百分比
    var profitLossPercentage: Double {
        guard totalCost > 0 else { return 0 }
        return (profitLoss / totalCost) * 100
    }
    
    /// 是否盈利
    var isProfitable: Bool {
        profitLoss >= 0
    }
    
    init(stockCode: String, stockName: String, market: MarketType, shares: Double, costPrice: Double, currentPrice: Double = 0.0) {
        self.stockCode = stockCode
        self.stockName = stockName
        self.market = market
        self.shares = shares
        self.costPrice = costPrice
        self.currentPrice = currentPrice
        self.addedDate = Date()
    }
}

/// 市场类型枚举
enum MarketType: String, CaseIterable, Codable {
    case usStock = "US" // 美股
    case hkStock = "HK" // 港股
    case cnStock = "CN" // A股
    
    var displayName: String {
        switch self {
        case .usStock:
            return "美股"
        case .hkStock:
            return "港股"
        case .cnStock:
            return "A股"
        }
    }
    
    var exchangeName: String {
        switch self {
        case .usStock:
            return "纳斯达克/纽交所"
        case .hkStock:
            return "香港交易所"
        case .cnStock:
            return "上海/深圳交易所"
        }
    }
}

/// 股票信息模型（用于搜索结果）
struct StockInfo: Identifiable, Codable {
    let id = UUID()
    let stockCode: String
    let stockName: String
    let market: MarketType
    let currentPrice: Double
    let changeAmount: Double // 涨跌额
    let changePercentage: Double // 涨跌幅
    
    var isPositive: Bool {
        changeAmount >= 0
    }
}
