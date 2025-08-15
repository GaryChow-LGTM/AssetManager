import Foundation

/// 资产数据模型
struct Asset: Identifiable, Codable, Hashable {
    let id = UUID()
    let stockCode: String // 股票代码
    let stockName: String // 股票名称
    let market: MarketType // 所属市场
    let currency: CurrencyType // 交易货币
    var shares: Double // 持股数量
    var costPrice: Double // 平均成本价（原币种）
    var currentPrice: Double // 当前价格（原币种）
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
    
    init(stockCode: String, stockName: String, market: MarketType, currency: CurrencyType? = nil, shares: Double, costPrice: Double, currentPrice: Double = 0.0) {
        self.stockCode = stockCode
        self.stockName = stockName
        self.market = market
        // 使用默认货币映射，避免MainActor问题
        self.currency = currency ?? Self.getDefaultCurrency(for: market)
        self.shares = shares
        self.costPrice = costPrice
        self.currentPrice = currentPrice
        self.addedDate = Date()
    }
    
    /// 获取市场的默认货币（静态方法，避免MainActor问题）
    private static func getDefaultCurrency(for market: MarketType) -> CurrencyType {
        switch market {
        case .cnStock:
            return .cny
        case .hkStock:
            return .hkd
        case .usStock:
            return .usd
        }
    }
    
    // MARK: - 基础格式化显示（使用简单格式，避免MainActor问题）
    
    /// 格式化显示当前价格
    var formattedCurrentPrice: String {
        return "\(currency.symbol)\(String(format: "%.2f", currentPrice))"
    }
    
    /// 格式化显示成本价
    var formattedCostPrice: String {
        return "\(currency.symbol)\(String(format: "%.2f", costPrice))"
    }
    
    /// 格式化显示当前市值
    var formattedCurrentValue: String {
        return "\(currency.symbol)\(String(format: "%.2f", currentValue))"
    }
    
    /// 格式化显示总成本
    var formattedTotalCost: String {
        return "\(currency.symbol)\(String(format: "%.2f", totalCost))"
    }
    
    /// 格式化显示盈亏金额
    var formattedProfitLoss: String {
        let amount = profitLoss
        let symbol = isProfitable ? "+" : ""
        return "\(symbol)\(currency.symbol)\(String(format: "%.2f", abs(amount)))"
    }
}

// MARK: - MainActor 扩展（需要MainActor上下文的方法）
@MainActor
extension Asset {
    /// 获取当前市值（指定货币）
    func getCurrentValue(in targetCurrency: CurrencyType) -> Double {
        return CurrencyService.shared.convert(amount: currentValue, from: currency, to: targetCurrency)
    }
    
    /// 获取总成本（指定货币）
    func getTotalCost(in targetCurrency: CurrencyType) -> Double {
        return CurrencyService.shared.convert(amount: totalCost, from: currency, to: targetCurrency)
    }
    
    /// 获取盈亏金额（指定货币）
    func getProfitLoss(in targetCurrency: CurrencyType) -> Double {
        return getCurrentValue(in: targetCurrency) - getTotalCost(in: targetCurrency)
    }
    
    /// 使用CurrencyService格式化显示当前价格
    var currencyFormattedCurrentPrice: String {
        return CurrencyService.shared.formatAmount(currentPrice, currency: currency)
    }
    
    /// 使用CurrencyService格式化显示成本价
    var currencyFormattedCostPrice: String {
        return CurrencyService.shared.formatAmount(costPrice, currency: currency)
    }
    
    /// 使用CurrencyService格式化显示当前市值
    var currencyFormattedCurrentValue: String {
        return CurrencyService.shared.formatAmount(currentValue, currency: currency)
    }
    
    /// 使用CurrencyService格式化显示总成本
    var currencyFormattedTotalCost: String {
        return CurrencyService.shared.formatAmount(totalCost, currency: currency)
    }
    
    /// 使用CurrencyService格式化显示盈亏金额
    var currencyFormattedProfitLoss: String {
        let amount = profitLoss
        let symbol = isProfitable ? "+" : ""
        return "\(symbol)\(CurrencyService.shared.formatAmount(abs(amount), currency: currency))"
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
