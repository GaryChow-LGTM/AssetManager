import Foundation

/// 投资组合快照模型（用于历史数据分析）
struct PortfolioSnapshot: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let totalValue: Double // 总市值（基准货币）
    let totalCost: Double // 总成本（基准货币）
    let totalProfitLoss: Double // 总盈亏（基准货币）
    let baseCurrency: CurrencyType // 基准货币
    let assetSnapshots: [AssetSnapshot] // 各资产快照
    
    /// 总投资回报率
    var totalReturn: Double {
        guard totalCost > 0 else { return 0 }
        return (totalProfitLoss / totalCost) * 100
    }
    
    /// 市场分布
    var marketDistribution: [MarketType: Double] {
        var distribution: [MarketType: Double] = [:]
        
        for snapshot in assetSnapshots {
            let currentValue = distribution[snapshot.market] ?? 0
            distribution[snapshot.market] = currentValue + snapshot.value
        }
        
        return distribution
    }
    
    /// 行业分布
    var industryDistribution: [IndustryType: Double] {
        var distribution: [IndustryType: Double] = [:]
        
        for snapshot in assetSnapshots {
            let currentValue = distribution[snapshot.industry] ?? 0
            distribution[snapshot.industry] = currentValue + snapshot.value
        }
        
        return distribution
    }
}

/// 单个资产快照
struct AssetSnapshot: Identifiable, Codable {
    var id = UUID()
    let stockCode: String
    let stockName: String
    let market: MarketType
    let industry: IndustryType
    let shares: Double
    let price: Double // 当时价格（原币种）
    let value: Double // 当时市值（基准货币）
    let currency: CurrencyType
    
    init(from asset: Asset, industry: IndustryType, baseCurrency: CurrencyType, convertedValue: Double) {
        self.id = UUID()
        self.stockCode = asset.stockCode
        self.stockName = asset.stockName
        self.market = asset.market
        self.industry = industry
        self.shares = asset.shares
        self.price = asset.currentPrice
        self.currency = asset.currency
        // 使用预先转换的值
        self.value = convertedValue
    }
}

/// 行业类型枚举
enum IndustryType: String, CaseIterable, Codable {
    case technology = "科技"
    case finance = "金融"
    case healthcare = "医疗"
    case consumer = "消费"
    case energy = "能源"
    case industrials = "工业"
    case realEstate = "房地产"
    case materials = "材料"
    case utilities = "公用事业"
    case communication = "通信"
    case other = "其他"
    
    var displayName: String {
        return rawValue
    }
    
    var color: String {
        switch self {
        case .technology:
            return "blue"
        case .finance:
            return "green"
        case .healthcare:
            return "red"
        case .consumer:
            return "orange"
        case .energy:
            return "yellow"
        case .industrials:
            return "purple"
        case .realEstate:
            return "pink"
        case .materials:
            return "brown"
        case .utilities:
            return "gray"
        case .communication:
            return "indigo"
        case .other:
            return "mint"
        }
    }
}

/// 时间范围枚举
enum TimeRange: String, CaseIterable {
    case week = "7天"
    case month = "1个月"
    case quarter = "3个月"
    case halfYear = "6个月"
    case year = "1年"
    case all = "全部"
    
    var days: Int {
        switch self {
        case .week:
            return 7
        case .month:
            return 30
        case .quarter:
            return 90
        case .halfYear:
            return 180
        case .year:
            return 365
        case .all:
            return Int.max
        }
    }
    
    var displayName: String {
        return rawValue
    }
}

/// P&L报告项
struct ProfitLossItem: Identifiable {
    let id = UUID()
    let stockCode: String
    let stockName: String
    let market: MarketType
    let industry: IndustryType
    let shares: Double
    let costPrice: Double
    let currentPrice: Double
    let profitLoss: Double
    let profitLossPercentage: Double
    let currency: CurrencyType
    
    var isProfitable: Bool {
        profitLoss >= 0
    }
}

/// 历史收益数据点
struct HistoryDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let returnRate: Double // 回报率
}
