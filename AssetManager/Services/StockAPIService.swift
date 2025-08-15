import Foundation
import Combine

/// 股票API服务协议
protocol StockAPIService {
    /// 搜索股票
    func searchStocks(query: String) async throws -> [StockInfo]
    
    /// 获取股票实时价格
    func getStockPrice(stockCode: String, market: MarketType) async throws -> StockInfo
    
    /// 批量获取股票价格
    func getStockPrices(for assets: [Asset]) async throws -> [String: Double]
}

/// 股票API错误类型
enum StockAPIError: Error, LocalizedError {
    case invalidStockCode
    case networkError
    case dataParsingError
    case stockNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidStockCode:
            return "无效的股票代码"
        case .networkError:
            return "网络连接失败"
        case .dataParsingError:
            return "数据解析错误"
        case .stockNotFound:
            return "未找到该股票"
        }
    }
}

/// 模拟股票API服务实现（使用真实股票数据）
class MockStockAPIService: StockAPIService {
    
    private let dataParser = StockDataParser.shared
    private var allStocks: [StockInfo] = []
    
    init() {
        // 异步加载数据
        Task {
            self.allStocks = await dataParser.loadStockData()
        }
    }
    
    /// 搜索股票
    func searchStocks(query: String) async throws -> [StockInfo] {
        // 确保数据已加载
        if allStocks.isEmpty {
            allStocks = await dataParser.loadStockData()
        }
        
        // 模拟网络延迟
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
        
        // 使用数据解析器的搜索功能
        let results = dataParser.searchStocks(query: query, limit: 50)
        
        return results
    }
    
    /// 获取单只股票价格
    func getStockPrice(stockCode: String, market: MarketType) async throws -> StockInfo {
        // 确保数据已加载
        if allStocks.isEmpty {
            allStocks = await dataParser.loadStockData()
        }
        
        // 模拟网络延迟
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
        
        guard let stock = dataParser.getStock(byCode: stockCode, market: market) else {
            throw StockAPIError.stockNotFound
        }
        
        // 模拟价格波动（±2%随机变化）
        let randomChange = Double.random(in: -0.02...0.02)
        let newPrice = stock.currentPrice * (1 + randomChange)
        let changeAmount = newPrice - stock.currentPrice
        let changePercentage = (changeAmount / stock.currentPrice) * 100
        
        return StockInfo(
            stockCode: stock.stockCode,
            stockName: stock.stockName,
            market: stock.market,
            currentPrice: newPrice,
            changeAmount: changeAmount,
            changePercentage: changePercentage
        )
    }
    
    /// 批量获取股票价格
    func getStockPrices(for assets: [Asset]) async throws -> [String: Double] {
        // 确保数据已加载
        if allStocks.isEmpty {
            allStocks = await dataParser.loadStockData()
        }
        
        // 模拟网络延迟
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        var prices: [String: Double] = [:]
        
        for asset in assets {
            let key = "\(asset.stockCode)_\(asset.market.rawValue)"
            if let stock = dataParser.getStock(byCode: asset.stockCode, market: asset.market) {
                // 模拟价格波动
                let randomChange = Double.random(in: -0.02...0.02)
                prices[key] = stock.currentPrice * (1 + randomChange)
            }
        }
        
        return prices
    }
}

/// 股票API服务管理器（单例）
class StockAPIManager: ObservableObject {
    static let shared = StockAPIManager()
    
    private let apiService: StockAPIService
    
    private init() {
        // 这里可以根据环境选择不同的实现
        self.apiService = MockStockAPIService()
    }
    
    var service: StockAPIService {
        return apiService
    }
}
