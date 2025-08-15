import Foundation
import SwiftUI

/// 投资组合分析服务
@MainActor
class PortfolioAnalysisService: ObservableObject {
    
    static let shared = PortfolioAnalysisService()
    
    @Published var snapshots: [PortfolioSnapshot] = []
    @Published var isAnalyzing = false
    
    private let userDefaults = UserDefaults.standard
    private let snapshotsKey = "PortfolioSnapshots"
    private let currencyService = CurrencyService.shared
    
    private init() {
        loadSnapshots()
    }
    
    // MARK: - 快照管理
    
    /// 创建当前投资组合快照
    func createSnapshot(from assets: [Asset]) async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let baseCurrency = currencyService.preferences.baseCurrency
        let date = Date()
        
        // 计算总值
        let totalValue = currencyService.calculateTotalValue(assets: assets)
        let totalCost = currencyService.calculateTotalCost(assets: assets)
        let totalProfitLoss = totalValue - totalCost
        
        // 创建资产快照
        var assetSnapshots: [AssetSnapshot] = []
        
        for asset in assets {
            let industry = getIndustryType(for: asset.stockCode, market: asset.market)
            let convertedValue = currencyService.convert(amount: asset.currentValue, from: asset.currency, to: baseCurrency)
            let snapshot = AssetSnapshot(
                from: asset,
                industry: industry,
                baseCurrency: baseCurrency,
                convertedValue: convertedValue
            )
            assetSnapshots.append(snapshot)
        }
        
        // 创建投资组合快照
        let portfolioSnapshot = PortfolioSnapshot(
            date: date,
            totalValue: totalValue,
            totalCost: totalCost,
            totalProfitLoss: totalProfitLoss,
            baseCurrency: baseCurrency,
            assetSnapshots: assetSnapshots
        )
        
        // 添加到快照列表
        snapshots.append(portfolioSnapshot)
        
        // 保持最近365天的数据
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -365, to: Date()) ?? Date()
        snapshots = snapshots.filter { $0.date >= cutoffDate }
        
        saveSnapshots()
    }
    
    /// 自动创建每日快照（如果今日还没有）
    func createDailySnapshotIfNeeded(from assets: [Asset]) async {
        let today = Calendar.current.startOfDay(for: Date())
        
        // 检查今日是否已有快照
        let hasToday = snapshots.contains { snapshot in
            Calendar.current.isDate(snapshot.date, inSameDayAs: today)
        }
        
        if !hasToday && !assets.isEmpty {
            await createSnapshot(from: assets)
        }
    }
    
    // MARK: - 历史数据查询
    
    /// 获取指定时间范围的快照
    func getSnapshots(for timeRange: TimeRange) -> [PortfolioSnapshot] {
        let calendar = Calendar.current
        let endDate = Date()
        
        let startDate: Date
        switch timeRange {
        case .all:
            return snapshots.sorted { $0.date < $1.date }
        default:
            startDate = calendar.date(byAdding: .day, value: -timeRange.days, to: endDate) ?? endDate
        }
        
        return snapshots
            .filter { $0.date >= startDate && $0.date <= endDate }
            .sorted { $0.date < $1.date }
    }
    
    /// 获取历史收益数据点
    func getHistoryDataPoints(for timeRange: TimeRange) -> [HistoryDataPoint] {
        let snapshots = getSnapshots(for: timeRange)
        guard let firstSnapshot = snapshots.first else { return [] }
        
        let initialValue = firstSnapshot.totalValue
        
        return snapshots.map { snapshot in
            let returnValue = initialValue > 0 ? ((snapshot.totalValue - initialValue) / initialValue) * 100 : 0
            return HistoryDataPoint(
                date: snapshot.date,
                value: snapshot.totalValue,
                returnRate: returnValue
            )
        }
    }
    
    // MARK: - 分析计算
    
    /// 计算总投资回报率
    func calculateTotalReturn(for timeRange: TimeRange) -> Double {
        let snapshots = getSnapshots(for: timeRange)
        guard let firstSnapshot = snapshots.first,
              let lastSnapshot = snapshots.last,
              firstSnapshot.totalCost > 0 else { return 0 }
        
        return ((lastSnapshot.totalValue - firstSnapshot.totalCost) / firstSnapshot.totalCost) * 100
    }
    
    /// 计算年化回报率
    func calculateAnnualizedReturn(for timeRange: TimeRange) -> Double {
        let snapshots = getSnapshots(for: timeRange)
        guard let firstSnapshot = snapshots.first,
              let lastSnapshot = snapshots.last,
              firstSnapshot.totalValue > 0 else { return 0 }
        
        let timeInterval = lastSnapshot.date.timeIntervalSince(firstSnapshot.date)
        let years = timeInterval / (365.25 * 24 * 3600) // 转换为年
        
        guard years > 0 else { return 0 }
        
        let totalReturn = lastSnapshot.totalValue / firstSnapshot.totalValue
        return (pow(totalReturn, 1.0 / years) - 1.0) * 100
    }
    
    /// 获取市场分布数据
    func getMarketDistribution(from assets: [Asset]) -> [(market: MarketType, value: Double, percentage: Double)] {
        let totalValue = currencyService.calculateTotalValue(assets: assets)
        guard totalValue > 0 else { return [] }
        
        var distribution: [MarketType: Double] = [:]
        
        for asset in assets {
            let valueInBaseCurrency = asset.getCurrentValue(in: currencyService.preferences.baseCurrency)
            let currentValue = distribution[asset.market] ?? 0
            distribution[asset.market] = currentValue + valueInBaseCurrency
        }
        
        return distribution.map { market, value in
            let percentage = (value / totalValue) * 100
            return (market: market, value: value, percentage: percentage)
        }.sorted { $0.value > $1.value }
    }
    
    /// 获取行业分布数据
    func getIndustryDistribution(from assets: [Asset]) -> [(industry: IndustryType, value: Double, percentage: Double)] {
        let totalValue = currencyService.calculateTotalValue(assets: assets)
        guard totalValue > 0 else { return [] }
        
        var distribution: [IndustryType: Double] = [:]
        
        for asset in assets {
            let industry = getIndustryType(for: asset.stockCode, market: asset.market)
            let valueInBaseCurrency = asset.getCurrentValue(in: currencyService.preferences.baseCurrency)
            let currentValue = distribution[industry] ?? 0
            distribution[industry] = currentValue + valueInBaseCurrency
        }
        
        return distribution.map { industry, value in
            let percentage = (value / totalValue) * 100
            return (industry: industry, value: value, percentage: percentage)
        }.sorted { $0.value > $1.value }
    }
    
    /// 生成P&L报告
    func generateProfitLossReport(from assets: [Asset], for timeRange: TimeRange = .all) -> [ProfitLossItem] {
        return assets.map { asset in
            let profitLoss = asset.profitLoss
            let profitLossPercentage = asset.profitLossPercentage
            let industry = getIndustryType(for: asset.stockCode, market: asset.market)
            
            return ProfitLossItem(
                stockCode: asset.stockCode,
                stockName: asset.stockName,
                market: asset.market,
                industry: industry,
                shares: asset.shares,
                costPrice: asset.costPrice,
                currentPrice: asset.currentPrice,
                profitLoss: profitLoss,
                profitLossPercentage: profitLossPercentage,
                currency: asset.currency
            )
        }.sorted { $0.profitLoss > $1.profitLoss }
    }
    
    /// 获取收益来源分布
    func getProfitSourceDistribution(from assets: [Asset]) -> [(type: String, value: Double, percentage: Double)] {
        let profitableAssets = assets.filter { $0.isProfitable }
        let totalProfit = profitableAssets.reduce(0) { $0 + $1.profitLoss }
        
        guard totalProfit > 0 else { return [] }
        
        var sources: [String: Double] = [:]
        
        for asset in profitableAssets {
            let industry = getIndustryType(for: asset.stockCode, market: asset.market)
            let currentProfit = sources[industry.displayName] ?? 0
            sources[industry.displayName] = currentProfit + asset.profitLoss
        }
        
        return sources.map { type, value in
            let percentage = (value / totalProfit) * 100
            return (type: type, value: value, percentage: percentage)
        }.sorted { $0.value > $1.value }
    }
    
    // MARK: - 行业分类
    
    /// 根据股票代码和市场判断行业类型
    private func getIndustryType(for stockCode: String, market: MarketType) -> IndustryType {
        let code = stockCode.uppercased()
        
        // 科技行业
        if isTechnologyStock(code: code, market: market) {
            return .technology
        }
        
        // 金融行业
        if isFinanceStock(code: code, market: market) {
            return .finance
        }
        
        // 医疗行业
        if isHealthcareStock(code: code, market: market) {
            return .healthcare
        }
        
        // 消费行业
        if isConsumerStock(code: code, market: market) {
            return .consumer
        }
        
        // 能源行业
        if isEnergyStock(code: code, market: market) {
            return .energy
        }
        
        // 工业
        if isIndustrialStock(code: code, market: market) {
            return .industrials
        }
        
        // 房地产
        if isRealEstateStock(code: code, market: market) {
            return .realEstate
        }
        
        // 通信
        if isCommunicationStock(code: code, market: market) {
            return .communication
        }
        
        return .other
    }
    
    // MARK: - 行业分类辅助方法
    
    private func isTechnologyStock(code: String, market: MarketType) -> Bool {
        let techStocks = [
            // 美股科技
            "AAPL", "MSFT", "GOOGL", "GOOG", "AMZN", "META", "TSLA", "NVDA", "AMD", "INTC",
            "CRM", "ORCL", "ADBE", "NFLX", "PYPL", "UBER", "SPOT", "SNAP", "TWTR", "SQ",
            
            // 港股科技
            "00700", "09988", "03690", "01024", "09618", "09999", "01833", "06060",
            "03888", "02013", "00772", "09866", "09626", "09961", "02518",
            
            // A股科技
            "000001", "002415", "300059", "002230", "002352", "000002", "600036", "300003"
        ]
        
        return techStocks.contains(code)
    }
    
    private func isFinanceStock(code: String, market: MarketType) -> Bool {
        let financeStocks = [
            // 美股金融
            "JPM", "BAC", "WFC", "GS", "MS", "C", "AXP", "BRK.A", "BRK.B", "V", "MA",
            
            // 港股金融  
            "00939", "01398", "03988", "02388", "01988", "06886", "02628", "01288",
            
            // A股金融
            "601398", "601939", "601288", "000001", "600036", "601328", "600000", "600519"
        ]
        
        return financeStocks.contains(code)
    }
    
    private func isHealthcareStock(code: String, market: MarketType) -> Bool {
        let healthcareStocks = [
            // 美股医疗
            "JNJ", "UNH", "PFE", "ABBV", "TMO", "ABT", "LLY", "DHR", "BMY", "MRK",
            
            // 港股医疗
            "01177", "06185", "09926", "02269", "01093", "09983",
            
            // A股医疗
            "000002", "600276", "000963", "002007", "300003", "600867"
        ]
        
        return healthcareStocks.contains(code)
    }
    
    private func isConsumerStock(code: String, market: MarketType) -> Bool {
        let consumerStocks = [
            // 美股消费
            "AMZN", "TSLA", "HD", "MCD", "NKE", "SBUX", "TGT", "LOW", "DIS", "COST",
            
            // 港股消费
            "02015", "01876", "00291", "01299", "02319", "00268",
            
            // A股消费
            "600519", "000858", "002304", "000568", "600887", "002142"
        ]
        
        return consumerStocks.contains(code)
    }
    
    private func isEnergyStock(code: String, market: MarketType) -> Bool {
        let energyStocks = [
            // 美股能源
            "XOM", "CVX", "COP", "EOG", "SLB", "MPC", "PSX", "VLO", "OXY", "DVN",
            
            // 港股能源
            "00857", "00883", "01193", "02883",
            
            // A股能源
            "601857", "600028", "601808", "000983"
        ]
        
        return energyStocks.contains(code)
    }
    
    private func isIndustrialStock(code: String, market: MarketType) -> Bool {
        let industrialStocks = [
            // 美股工业
            "BA", "CAT", "HON", "UPS", "RTX", "LMT", "DE", "FDX", "GE", "MMM",
            
            // 港股工业
            "00700", "00001", "00883", "00939",
            
            // A股工业
            "600900", "000002", "601111", "600150"
        ]
        
        return industrialStocks.contains(code)
    }
    
    private func isRealEstateStock(code: String, market: MarketType) -> Bool {
        let realEstateStocks = [
            // 美股房地产
            "AMT", "CCI", "PLD", "EQIX", "SPG", "O", "PSA", "EXR", "AVB", "EQR",
            
            // 港股房地产
            "00016", "01997", "00012", "01109", "00101",
            
            // A股房地产
            "000002", "600000", "001979", "600048"
        ]
        
        return realEstateStocks.contains(code)
    }
    
    private func isCommunicationStock(code: String, market: MarketType) -> Bool {
        let communicationStocks = [
            // 美股通信
            "META", "GOOGL", "GOOG", "NFLX", "DIS", "CMCSA", "VZ", "T", "TMUS", "CHTR",
            
            // 港股通信
            "00700", "00762", "00728", "01024",
            
            // A股通信
            "000063", "600050", "000839", "002415"
        ]
        
        return communicationStocks.contains(code)
    }
    
    // MARK: - 数据持久化
    
    private func saveSnapshots() {
        if let encoded = try? JSONEncoder().encode(snapshots) {
            userDefaults.set(encoded, forKey: snapshotsKey)
        }
    }
    
    private func loadSnapshots() {
        if let data = userDefaults.data(forKey: snapshotsKey),
           let decoded = try? JSONDecoder().decode([PortfolioSnapshot].self, from: data) {
            self.snapshots = decoded
        }
    }
    
    /// 清除所有历史数据
    func clearAllSnapshots() {
        snapshots.removeAll()
        saveSnapshots()
    }
}
