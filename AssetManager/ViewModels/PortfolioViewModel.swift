import Foundation
import SwiftUI
import Combine

/// 资产组合管理ViewModel
@MainActor
class PortfolioViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var assets: [Asset] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isRefreshing = false
    
    // MARK: - Currency Service
    private let currencyService = CurrencyService.shared
    
    // MARK: - Computed Properties
    
    /// 总资产市值（基准货币）
    var totalValue: Double {
        currencyService.calculateTotalValue(assets: assets)
    }
    
    /// 总成本（基准货币）
    var totalCost: Double {
        currencyService.calculateTotalCost(assets: assets)
    }
    
    /// 基准货币
    var baseCurrency: CurrencyType {
        currencyService.preferences.baseCurrency
    }
    
    /// 总盈亏金额
    var totalProfitLoss: Double {
        totalValue - totalCost
    }
    
    /// 总盈亏百分比
    var totalProfitLossPercentage: Double {
        guard totalCost > 0 else { return 0 }
        return (totalProfitLoss / totalCost) * 100
    }
    
    /// 是否总体盈利
    var isTotalProfitable: Bool {
        totalProfitLoss >= 0
    }
    
    /// 按市场分组的资产
    var assetsByMarket: [MarketType: [Asset]] {
        Dictionary(grouping: assets) { $0.market }
    }
    
    /// 市场分布数据（用于饼图）
    var marketDistribution: [(market: MarketType, value: Double, percentage: Double)] {
        let marketValues = assetsByMarket.mapValues { assets in
            assets.reduce(0) { $0 + $1.currentValue }
        }
        
        return marketValues.compactMap { market, value in
            guard totalValue > 0 else { return nil }
            let percentage = (value / totalValue) * 100
            return (market: market, value: value, percentage: percentage)
        }.sorted { $0.value > $1.value }
    }
    
    /// 个股分布数据（用于饼图，显示前10大持仓）
    var stockDistribution: [(asset: Asset, percentage: Double)] {
        guard totalValue > 0 else { return [] }
        
        return assets
            .map { asset in
                let assetValueInBaseCurrency = asset.getCurrentValue(in: baseCurrency)
                let percentage = (assetValueInBaseCurrency / totalValue) * 100
                return (asset: asset, percentage: percentage)
            }
            .sorted { $0.percentage > $1.percentage }
            .prefix(10)
            .map { $0 }
    }
    
    /// 货币分布数据（用于饼图）
    var currencyDistribution: [(currency: CurrencyType, value: Double, percentage: Double)] {
        let currencyValues = Dictionary(grouping: assets) { $0.currency }
            .mapValues { assets in
                assets.reduce(0) { total, asset in
                    total + asset.getCurrentValue(in: baseCurrency)
                }
            }
        
        return currencyValues.compactMap { currency, value in
            guard totalValue > 0 else { return nil }
            let percentage = (value / totalValue) * 100
            return (currency: currency, value: value, percentage: percentage)
        }.sorted { $0.value > $1.value }
    }
    

    
    // MARK: - Private Properties
    private let stockAPIService: StockAPIService
    private let analysisService = PortfolioAnalysisService.shared
    private var refreshTimer: Timer?
    private let userDefaults = UserDefaults.standard
    private let assetsKey = "SavedAssets"
    
    // MARK: - Initialization
    init(stockAPIService: StockAPIService = StockAPIManager.shared.service) {
        self.stockAPIService = stockAPIService
        loadAssets()
        startAutoRefresh()
    }
    
    deinit {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Public Methods
    
    /// 添加资产
    func addAsset(_ asset: Asset) {
        // 如果已存在相同标的（以股票代码 + 市场为唯一标识），执行加仓合并
        if let index = assets.firstIndex(where: { $0.stockCode == asset.stockCode && $0.market == asset.market }) {
            var existing = assets[index]
            let existingShares = existing.shares
            let newShares = asset.shares
            let totalShares = existingShares + newShares

            if totalShares > 0 {
                // 将新增持仓总成本换算到现有持仓币种后再加权
                let existingCurrency = existing.currency
                let existingTotalCost = existingShares * existing.costPrice
                let addedTotalCostOriginal = newShares * asset.costPrice
                let addedTotalCostInExistingCurrency: Double
                if asset.currency == existingCurrency {
                    addedTotalCostInExistingCurrency = addedTotalCostOriginal
                } else {
                    addedTotalCostInExistingCurrency = CurrencyService.shared.convert(
                        amount: addedTotalCostOriginal,
                        from: asset.currency,
                        to: existingCurrency
                    )
                }

                let mergedTotalCost = existingTotalCost + addedTotalCostInExistingCurrency
                let mergedCostPrice = mergedTotalCost / totalShares

                // 就地更新，保留既有 id、名称、市场、币种等
                existing.shares = totalShares
                existing.costPrice = mergedCostPrice
                // currentPrice 保持不变，稍后刷新
                assets[index] = existing
            }

            saveAssets()

            // 合并后刷新该标的价格与分析
            Task {
                await refreshAssetPrice(assets[index])
                await updatePortfolioAnalysis()
            }
        } else {
            // 不存在则直接新增
            assets.append(asset)
            saveAssets()
            
            // 立即更新新添加资产的价格与分析
            Task {
                await refreshAssetPrice(asset)
                await updatePortfolioAnalysis()
            }
        }
    }
    
    /// 删除资产
    func removeAsset(_ asset: Asset) {
        assets.removeAll { $0.id == asset.id }
        saveAssets()
        
        // 删除资产后立即更新投资组合深度分析
        Task {
            await updatePortfolioAnalysis()
        }
    }
    
    /// 更新资产
    func updateAsset(_ asset: Asset) {
        if let index = assets.firstIndex(where: { $0.id == asset.id }) {
            assets[index] = asset
            saveAssets()
            
            // 更新资产后立即更新投资组合深度分析
            Task {
                await updatePortfolioAnalysis()
            }
        }
    }
    
    /// 刷新所有资产价格
    func refreshAllPrices() async {
        guard !assets.isEmpty else { return }
        
        isRefreshing = true
        errorMessage = nil
        
        do {
            let prices = try await stockAPIService.getStockPrices(for: assets)
            
            for index in assets.indices {
                let asset = assets[index]
                let key = "\(asset.stockCode)_\(asset.market.rawValue)"
                if let newPrice = prices[key] {
                    assets[index] = Asset(
                        stockCode: asset.stockCode,
                        stockName: asset.stockName,
                        market: asset.market,
                        currency: asset.currency,
                        shares: asset.shares,
                        costPrice: asset.costPrice,
                        currentPrice: newPrice,
                        purchaseDate: asset.purchaseDate
                    )
                }
            }
            
            saveAssets()
            
            // 价格更新后立即更新投资组合深度分析
            await updatePortfolioAnalysis()
        } catch {
            errorMessage = "价格更新失败: \(error.localizedDescription)"
        }
        
        isRefreshing = false
    }
    
    /// 刷新单个资产价格
    func refreshAssetPrice(_ asset: Asset) async {
        do {
            let stockInfo = try await stockAPIService.getStockPrice(
                stockCode: asset.stockCode,
                market: asset.market
            )
            
            if let index = assets.firstIndex(where: { $0.id == asset.id }) {
                assets[index] = Asset(
                    stockCode: asset.stockCode,
                    stockName: asset.stockName,
                    market: asset.market,
                    currency: asset.currency,
                    shares: asset.shares,
                    costPrice: asset.costPrice,
                    currentPrice: stockInfo.currentPrice,
                    purchaseDate: asset.purchaseDate
                )
                saveAssets()
            }
        } catch {
            errorMessage = "价格更新失败: \(error.localizedDescription)"
        }
    }
    
    /// 更新投资组合深度分析
    private func updatePortfolioAnalysis() async {
        guard !assets.isEmpty else { return }
        
        // 创建新的投资组合快照以更新深度分析
        await analysisService.createSnapshot(from: assets)
    }
    
    /// 手动刷新
    func manualRefresh() {
        Task {
            await refreshAllPrices()
        }
    }
    
    /// 清除错误消息
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Currency Formatting
    
    /// 格式化总资产显示
    var formattedTotalValue: String {
        return currencyService.formatAmount(totalValue, currency: baseCurrency)
    }
    
    /// 格式化总成本显示
    var formattedTotalCost: String {
        return currencyService.formatAmount(totalCost, currency: baseCurrency)
    }
    
    /// 格式化总盈亏显示
    var formattedTotalProfitLoss: String {
        let symbol = isTotalProfitable ? "+" : ""
        return "\(symbol)\(currencyService.formatAmount(totalProfitLoss, currency: baseCurrency))"
    }
    
    // MARK: - Private Methods
    
    /// 加载保存的资产
    private func loadAssets() {
        if let data = userDefaults.data(forKey: assetsKey),
           let decodedAssets = try? JSONDecoder().decode([Asset].self, from: data) {
            self.assets = decodedAssets
        }
    }
    
    /// 保存资产到本地
    private func saveAssets() {
        if let encoded = try? JSONEncoder().encode(assets) {
            userDefaults.set(encoded, forKey: assetsKey)
        }
    }
    
    /// 开始自动刷新
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            Task { @MainActor in
                await self.refreshAllPrices()
            }
        }
    }
    
    /// 停止自动刷新
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Sample Data
extension PortfolioViewModel {
    /// 添加示例数据（用于预览和测试）
    func addSampleData() {
        Task {
            // 等待股票数据加载完成
            let allStocks = await StockDataParser.shared.loadStockData()
            
            // 从真实数据中选择一些热门股票作为示例
            let sampleStockCodes = [
                ("AAPL", MarketType.usStock),     // 苹果
                ("MSFT", MarketType.usStock),     // 微软
                ("00700", MarketType.hkStock),    // 腾讯控股
                ("09988", MarketType.hkStock),    // 阿里巴巴
                ("600519", MarketType.cnStock),   // 贵州茅台
                ("000858", MarketType.cnStock)    // 五粮液
            ]
            
            var sampleAssets: [Asset] = []
            
            for (code, market) in sampleStockCodes {
                if let stock = StockDataParser.shared.getStock(byCode: code, market: market) {
                    let shares: Double = market == .cnStock ? Double.random(in: 10...100) : Double.random(in: 50...500)
                    let costPriceRatio = Double.random(in: 0.8...1.2) // 成本价相对当前价格的比例
                    let costPrice = stock.currentPrice * costPriceRatio
                    
                    let currency = currencyService.getDefaultCurrency(for: market)
                    
                    // 生成随机的购入时间（过去30-365天内）
                    let daysAgo = Int.random(in: 30...365)
                    let purchaseDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
                    
                    let asset = Asset(
                        stockCode: stock.stockCode,
                        stockName: stock.stockName,
                        market: market,
                        currency: currency,
                        shares: shares,
                        costPrice: costPrice,
                        currentPrice: stock.currentPrice,
                        purchaseDate: purchaseDate
                    )
                    sampleAssets.append(asset)
                }
            }
            
            // 在主线程添加资产
            await MainActor.run {
                for asset in sampleAssets {
                    addAsset(asset)
                }
            }
        }
    }
}
