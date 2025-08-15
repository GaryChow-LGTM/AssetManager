import Foundation
import SwiftUI
import Combine

/// 资产组合管理ViewModel
@MainActor
class PortfolioViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var assets: [Asset] = []
    @Published var selectedGroupId: String? = nil // nil 表示“全部”
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isRefreshing = false
    
    // MARK: - Currency Service
    private let currencyService = CurrencyService.shared
    
    // MARK: - Computed Properties
    
    /// 总资产市值（基准货币）
    var totalValue: Double {
        currencyService.calculateTotalValue(assets: filteredAssets)
    }
    
    /// 总成本（基准货币）
    var totalCost: Double {
        currencyService.calculateTotalCost(assets: filteredAssets)
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
        Dictionary(grouping: filteredAssets) { $0.market }
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
        
        return filteredAssets
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
        let currencyValues = Dictionary(grouping: filteredAssets) { $0.currency }
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

    /// 基于所选分组过滤后的资产
    var filteredAssets: [Asset] {
        guard let gid = selectedGroupId else { return assets }
        return assets.filter { $0.groupId == gid }
    }

    // MARK: - Group Ops
    func assign(_ asset: Asset, to groupId: String?) {
        if let index = assets.firstIndex(where: { $0.id == asset.id }) {
            var updated = assets[index]
            updated.groupId = groupId
            assets[index] = updated
            saveAssets()
        }
    }

    func unassignGroup(for groupId: String) {
        var changed = false
        for i in assets.indices {
            if assets[i].groupId == groupId {
                assets[i].groupId = nil
                changed = true
            }
        }
        if changed { saveAssets() }
    }
    

    
    // MARK: - Private Properties
    private let stockAPIService: StockAPIService
    private let analysisService = PortfolioAnalysisService.shared
    private let transactionStore = TransactionStore.shared
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

        // 同步记录买入交易（费用默认为0）
        let buyTx = Transaction(
            stockCode: asset.stockCode,
            stockName: asset.stockName,
            market: asset.market,
            currency: asset.currency,
            type: .buy,
            shares: asset.shares,
            price: asset.costPrice,
            fees: 0,
            date: asset.purchaseDate
        )
        transactionStore.add(buyTx)
    }
    
    /// 卖出资产（部分或全部）
    func sellAsset(_ asset: Asset, soldShares: Double, sellPrice: Double, sellDate: Date = Date(), fees: Double = 0) {
        guard soldShares > 0, sellPrice > 0, fees >= 0 else {
            errorMessage = "卖出参数非法"
            return
        }
        guard let index = assets.firstIndex(where: { $0.id == asset.id }) else {
            errorMessage = "未找到待卖出的资产"
            return
        }
        let current = assets[index]
        guard soldShares <= current.shares else {
            errorMessage = "卖出数量超过持仓数量"
            return
        }

        let remainingShares = current.shares - soldShares

        if remainingShares > 0 {
            // 保持加权平均成本不变，仅减少持仓数量
            let updated = Asset(
                stockCode: current.stockCode,
                stockName: current.stockName,
                market: current.market,
                currency: current.currency,
                shares: remainingShares,
                costPrice: current.costPrice,
                currentPrice: current.currentPrice,
                purchaseDate: current.purchaseDate,
                groupId: current.groupId
            )
            assets[index] = updated
        } else {
            // 全部卖出则移除资产
            assets.remove(at: index)
        }

        saveAssets()

        // 卖出后更新投资组合深度分析
        Task {
            await updatePortfolioAnalysis()
        }

        // 记录卖出交易（含已实现盈亏）
        let realizedPL = (sellPrice - current.costPrice) * soldShares - fees
        let sellTx = Transaction(
            stockCode: current.stockCode,
            stockName: current.stockName,
            market: current.market,
            currency: current.currency,
            type: .sell,
            shares: soldShares,
            price: sellPrice,
            fees: fees,
            date: sellDate,
            realizedProfitLoss: realizedPL
        )
        transactionStore.add(sellTx)
    }

    /// 详情页加仓当前标的（记录费用到交易，不调整成本价公式，仍按加权平均合并）
    func buyMore(for asset: Asset, shares: Double, price: Double, date: Date = Date(), fees: Double = 0) {
        guard shares > 0, price > 0, fees >= 0 else {
            errorMessage = "买入参数非法"
            return
        }
        // 合并到现有持仓：复用 addAsset 的加权逻辑
        let lot = Asset(
            stockCode: asset.stockCode,
            stockName: asset.stockName,
            market: asset.market,
            currency: asset.currency,
            shares: shares,
            costPrice: price,
            currentPrice: asset.currentPrice,
            purchaseDate: date
        )
        addAsset(lot)

        // 写入买入交易（包含费用）
        let buyTx = Transaction(
            stockCode: asset.stockCode,
            stockName: asset.stockName,
            market: asset.market,
            currency: asset.currency,
            type: .buy,
            shares: shares,
            price: price,
            fees: fees,
            date: date
        )
        transactionStore.add(buyTx)
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
                        purchaseDate: asset.purchaseDate,
                        groupId: asset.groupId
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
                    purchaseDate: asset.purchaseDate,
                    groupId: asset.groupId
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
