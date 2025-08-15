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
    
    // MARK: - Computed Properties
    
    /// 总资产市值
    var totalValue: Double {
        assets.reduce(0) { $0 + $1.currentValue }
    }
    
    /// 总成本
    var totalCost: Double {
        assets.reduce(0) { $0 + $1.totalCost }
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
                let percentage = (asset.currentValue / totalValue) * 100
                return (asset: asset, percentage: percentage)
            }
            .sorted { $0.percentage > $1.percentage }
            .prefix(10)
            .map { $0 }
    }
    
    // MARK: - Private Properties
    private let stockAPIService: StockAPIService
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
        assets.append(asset)
        saveAssets()
        
        // 立即更新新添加资产的价格
        Task {
            await refreshAssetPrice(asset)
        }
    }
    
    /// 删除资产
    func removeAsset(_ asset: Asset) {
        assets.removeAll { $0.id == asset.id }
        saveAssets()
    }
    
    /// 更新资产
    func updateAsset(_ asset: Asset) {
        if let index = assets.firstIndex(where: { $0.id == asset.id }) {
            assets[index] = asset
            saveAssets()
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
                        shares: asset.shares,
                        costPrice: asset.costPrice,
                        currentPrice: newPrice
                    )
                }
            }
            
            saveAssets()
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
                    shares: asset.shares,
                    costPrice: asset.costPrice,
                    currentPrice: stockInfo.currentPrice
                )
                saveAssets()
            }
        } catch {
            errorMessage = "价格更新失败: \(error.localizedDescription)"
        }
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
        let sampleAssets = [
            Asset(stockCode: "AAPL", stockName: "苹果公司", market: .usStock, 
                  shares: 100, costPrice: 150.0, currentPrice: 178.25),
            Asset(stockCode: "00700", stockName: "腾讯控股", market: .hkStock, 
                  shares: 200, costPrice: 350.0, currentPrice: 368.80),
            Asset(stockCode: "600519", stockName: "贵州茅台", market: .cnStock, 
                  shares: 10, costPrice: 1600.0, currentPrice: 1680.0)
        ]
        
        for asset in sampleAssets {
            addAsset(asset)
        }
    }
}
