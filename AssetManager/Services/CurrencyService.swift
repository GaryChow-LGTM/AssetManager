import Foundation

/// 汇率管理服务
@MainActor
class CurrencyService: ObservableObject {
    
    static let shared = CurrencyService()
    
    @Published var preferences: CurrencyPreferences
    @Published var exchangeRates: [String: Double] = [:]
    
    private let userDefaults = UserDefaults.standard
    private let preferencesKey = "CurrencyPreferences"
    private let exchangeRatesKey = "ExchangeRates"
    
    private init() {
        // 加载用户偏好
        if let data = userDefaults.data(forKey: preferencesKey),
           let preferences = try? JSONDecoder().decode(CurrencyPreferences.self, from: data) {
            self.preferences = preferences
        } else {
            self.preferences = CurrencyPreferences()
        }
        
        // 加载汇率数据
        if let savedRates = userDefaults.object(forKey: exchangeRatesKey) as? [String: Double] {
            self.exchangeRates = savedRates
        } else {
            // 初始化默认汇率
            initializeDefaultExchangeRates()
        }
    }
    
    /// 初始化默认汇率（以人民币为基准）
    private func initializeDefaultExchangeRates() {
        exchangeRates = [
            // CNY -> 其他货币
            "CNY_USD": 0.14,  // 1人民币 = 0.14美元
            "CNY_HKD": 1.10,  // 1人民币 = 1.10港币
            
            // USD -> 其他货币
            "USD_CNY": 7.20,  // 1美元 = 7.20人民币
            "USD_HKD": 7.80,  // 1美元 = 7.80港币
            
            // HKD -> 其他货币
            "HKD_CNY": 0.91,  // 1港币 = 0.91人民币
            "HKD_USD": 0.13,  // 1港币 = 0.13美元
            
            // 同币种汇率
            "CNY_CNY": 1.0,
            "USD_USD": 1.0,
            "HKD_HKD": 1.0
        ]
        
        saveExchangeRates()
    }
    
    /// 获取汇率
    func getExchangeRate(from: CurrencyType, to: CurrencyType) -> Double {
        if from == to {
            return 1.0
        }
        
        let key = CurrencyPreferences.rateKey(from: from, to: to)
        
        // 优先使用用户自定义汇率
        if let customRate = preferences.customExchangeRates[key] {
            return customRate
        }
        
        // 使用默认汇率
        return exchangeRates[key] ?? 1.0
    }
    
    /// 转换货币金额
    func convert(amount: Double, from: CurrencyType, to: CurrencyType) -> Double {
        let rate = getExchangeRate(from: from, to: to)
        return amount * rate
    }
    
    /// 转换货币金额对象
    func convert(currencyAmount: CurrencyAmount, to targetCurrency: CurrencyType) -> CurrencyAmount {
        let convertedAmount = convert(
            amount: currencyAmount.amount,
            from: currencyAmount.currency,
            to: targetCurrency
        )
        return CurrencyAmount(amount: convertedAmount, currency: targetCurrency)
    }
    
    /// 更新基准货币
    func updateBaseCurrency(_ currency: CurrencyType) {
        preferences.baseCurrency = currency
        savePreferences()
    }
    
    /// 更新自定义汇率
    func updateCustomExchangeRate(from: CurrencyType, to: CurrencyType, rate: Double) {
        let key = CurrencyPreferences.rateKey(from: from, to: to)
        preferences.customExchangeRates[key] = rate
        
        // 同时更新反向汇率
        let reverseKey = CurrencyPreferences.rateKey(from: to, to: from)
        if rate > 0 {
            preferences.customExchangeRates[reverseKey] = 1.0 / rate
        }
        
        savePreferences()
    }
    
    /// 重置汇率为默认值
    func resetExchangeRates() {
        preferences.customExchangeRates.removeAll()
        initializeDefaultExchangeRates()
        savePreferences()
    }
    
    /// 获取所有可用的汇率对
    func getAllExchangeRatePairs() -> [(from: CurrencyType, to: CurrencyType, rate: Double)] {
        var pairs: [(from: CurrencyType, to: CurrencyType, rate: Double)] = []
        
        for fromCurrency in CurrencyType.allCases {
            for toCurrency in CurrencyType.allCases {
                if fromCurrency != toCurrency {
                    let rate = getExchangeRate(from: fromCurrency, to: toCurrency)
                    pairs.append((from: fromCurrency, to: toCurrency, rate: rate))
                }
            }
        }
        
        return pairs
    }
    
    /// 根据市场类型获取默认货币
    func getDefaultCurrency(for market: MarketType) -> CurrencyType {
        switch market {
        case .cnStock:
            return .cny
        case .hkStock:
            return .hkd
        case .usStock:
            return .usd
        }
    }
    
    /// 格式化金额显示
    func formatAmount(_ amount: Double, currency: CurrencyType) -> String {
        return "\(currency.symbol)\(String(format: "%.2f", amount))"
    }
    
    /// 格式化金额显示（带基准货币转换）
    func formatAmountWithConversion(_ amount: Double, currency: CurrencyType) -> String {
        let baseCurrency = preferences.baseCurrency
        
        if currency == baseCurrency {
            return formatAmount(amount, currency: currency)
        }
        
        let convertedAmount = convert(amount: amount, from: currency, to: baseCurrency)
        let originalFormatted = formatAmount(amount, currency: currency)
        let convertedFormatted = formatAmount(convertedAmount, currency: baseCurrency)
        
        return "\(originalFormatted) (\(convertedFormatted))"
    }
    
    // MARK: - 数据持久化
    
    private func savePreferences() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            userDefaults.set(encoded, forKey: preferencesKey)
        }
    }
    
    private func saveExchangeRates() {
        userDefaults.set(exchangeRates, forKey: exchangeRatesKey)
    }
}

// MARK: - 汇率计算扩展
extension CurrencyService {
    
    /// 计算投资组合总值（转换为基准货币）
    func calculateTotalValue(assets: [Asset]) -> Double {
        let baseCurrency = preferences.baseCurrency
        
        return assets.reduce(0) { total, asset in
            let assetValue = asset.currentValue
            let assetCurrency = getDefaultCurrency(for: asset.market)
            let convertedValue = convert(amount: assetValue, from: assetCurrency, to: baseCurrency)
            return total + convertedValue
        }
    }
    
    /// 计算投资组合总成本（转换为基准货币）
    func calculateTotalCost(assets: [Asset]) -> Double {
        let baseCurrency = preferences.baseCurrency
        
        return assets.reduce(0) { total, asset in
            let assetCost = asset.totalCost
            let assetCurrency = getDefaultCurrency(for: asset.market)
            let convertedCost = convert(amount: assetCost, from: assetCurrency, to: baseCurrency)
            return total + convertedCost
        }
    }
    
    /// 按货币类型分组统计资产
    func groupAssetsByCurrency(assets: [Asset]) -> [CurrencyType: (value: Double, cost: Double)] {
        var grouped: [CurrencyType: (value: Double, cost: Double)] = [:]
        
        for asset in assets {
            let currency = getDefaultCurrency(for: asset.market)
            let currentGroup = grouped[currency] ?? (value: 0, cost: 0)
            grouped[currency] = (
                value: currentGroup.value + asset.currentValue,
                cost: currentGroup.cost + asset.totalCost
            )
        }
        
        return grouped
    }
}
