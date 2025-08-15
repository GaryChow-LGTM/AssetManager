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

/// 模拟股票API服务实现
class MockStockAPIService: StockAPIService {
    
    private let mockStocks: [StockInfo] = [
        // 美股
        StockInfo(stockCode: "AAPL", stockName: "苹果公司", market: .usStock, 
                 currentPrice: 178.25, changeAmount: 2.15, changePercentage: 1.22),
        StockInfo(stockCode: "MSFT", stockName: "微软公司", market: .usStock, 
                 currentPrice: 378.85, changeAmount: -1.20, changePercentage: -0.32),
        StockInfo(stockCode: "GOOGL", stockName: "谷歌公司", market: .usStock, 
                 currentPrice: 138.45, changeAmount: 0.85, changePercentage: 0.62),
        StockInfo(stockCode: "TSLA", stockName: "特斯拉公司", market: .usStock, 
                 currentPrice: 248.50, changeAmount: -5.30, changePercentage: -2.09),
        
        // 港股
        StockInfo(stockCode: "00700", stockName: "腾讯控股", market: .hkStock, 
                 currentPrice: 368.80, changeAmount: 8.20, changePercentage: 2.27),
        StockInfo(stockCode: "09988", stockName: "阿里巴巴-SW", market: .hkStock, 
                 currentPrice: 78.45, changeAmount: -1.15, changePercentage: -1.44),
        StockInfo(stockCode: "01024", stockName: "快手-W", market: .hkStock, 
                 currentPrice: 52.30, changeAmount: 1.80, changePercentage: 3.57),
        StockInfo(stockCode: "03690", stockName: "美团-W", market: .hkStock, 
                 currentPrice: 148.60, changeAmount: -2.40, changePercentage: -1.59),
        
        // A股
        StockInfo(stockCode: "600519", stockName: "贵州茅台", market: .cnStock, 
                 currentPrice: 1680.00, changeAmount: 15.50, changePercentage: 0.93),
        StockInfo(stockCode: "000858", stockName: "五粮液", market: .cnStock, 
                 currentPrice: 128.45, changeAmount: -2.35, changePercentage: -1.80),
        StockInfo(stockCode: "000001", stockName: "平安银行", market: .cnStock, 
                 currentPrice: 12.85, changeAmount: 0.15, changePercentage: 1.18),
        StockInfo(stockCode: "300750", stockName: "宁德时代", market: .cnStock, 
                 currentPrice: 178.88, changeAmount: 3.22, changePercentage: 1.83)
    ]
    
    /// 搜索股票
    func searchStocks(query: String) async throws -> [StockInfo] {
        // 模拟网络延迟
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        let lowercaseQuery = query.lowercased()
        let results = mockStocks.filter { stock in
            stock.stockCode.lowercased().contains(lowercaseQuery) ||
            stock.stockName.lowercased().contains(lowercaseQuery)
        }
        
        return results
    }
    
    /// 获取单只股票价格
    func getStockPrice(stockCode: String, market: MarketType) async throws -> StockInfo {
        // 模拟网络延迟
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
        
        guard let stock = mockStocks.first(where: { $0.stockCode == stockCode && $0.market == market }) else {
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
        // 模拟网络延迟
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8秒
        
        var prices: [String: Double] = [:]
        
        for asset in assets {
            let key = "\(asset.stockCode)_\(asset.market.rawValue)"
            if let stock = mockStocks.first(where: { $0.stockCode == asset.stockCode && $0.market == asset.market }) {
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
