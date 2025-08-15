import Foundation

/// 货币类型枚举
enum CurrencyType: String, CaseIterable, Codable {
    case cny = "CNY" // 人民币
    case hkd = "HKD" // 港币
    case usd = "USD" // 美元
    
    /// 货币显示名称
    var displayName: String {
        switch self {
        case .cny:
            return "人民币"
        case .hkd:
            return "港币"
        case .usd:
            return "美元"
        }
    }
    
    /// 货币符号
    var symbol: String {
        switch self {
        case .cny:
            return "¥"
        case .hkd:
            return "HK$"
        case .usd:
            return "$"
        }
    }
    
    /// 货币代码
    var code: String {
        return rawValue
    }
    
    /// 默认与市场的关联
    var defaultMarket: MarketType? {
        switch self {
        case .cny:
            return .cnStock
        case .hkd:
            return .hkStock
        case .usd:
            return .usStock
        }
    }
}

/// 汇率信息模型
struct ExchangeRate: Codable, Identifiable {
    let id = UUID()
    let fromCurrency: CurrencyType
    let toCurrency: CurrencyType
    var rate: Double
    let lastUpdated: Date
    
    init(from: CurrencyType, to: CurrencyType, rate: Double) {
        self.fromCurrency = from
        self.toCurrency = to
        self.rate = rate
        self.lastUpdated = Date()
    }
}

/// 货币金额模型
struct CurrencyAmount: Codable {
    let amount: Double
    let currency: CurrencyType
    
    /// 格式化显示
    var formatted: String {
        return "\(currency.symbol)\(String(format: "%.2f", amount))"
    }
    
    /// 转换为其他货币
    func convert(to targetCurrency: CurrencyType, using exchangeRates: [String: Double]) -> CurrencyAmount? {
        if currency == targetCurrency {
            return self
        }
        
        let key = "\(currency.rawValue)_\(targetCurrency.rawValue)"
        
        if let rate = exchangeRates[key] {
            let convertedAmount = amount * rate
            return CurrencyAmount(amount: convertedAmount, currency: targetCurrency)
        }
        
        return nil
    }
}

/// 用户货币偏好设置
struct CurrencyPreferences: Codable {
    var baseCurrency: CurrencyType
    var customExchangeRates: [String: Double]
    
    init(baseCurrency: CurrencyType = .cny) {
        self.baseCurrency = baseCurrency
        self.customExchangeRates = [:]
    }
    
    /// 获取汇率键
    static func rateKey(from: CurrencyType, to: CurrencyType) -> String {
        return "\(from.rawValue)_\(to.rawValue)"
    }
}
