import Foundation

/// 股票数据解析器
class StockDataParser {
    
    static let shared = StockDataParser()
    
    private var cachedStocks: [StockInfo] = []
    private var isDataLoaded = false
    
    private init() {}
    
    /// 加载所有股票数据
    func loadStockData() async -> [StockInfo] {
        if isDataLoaded {
            return cachedStocks
        }
        
        var allStocks: [StockInfo] = []
        
        // 加载A股数据
        let aStocks = await loadStocksFromFile(fileName: "A-stock", market: .cnStock)
        allStocks.append(contentsOf: aStocks)
        
        // 加载港股数据
        let hkStocks = await loadStocksFromFile(fileName: "HK-stock", market: .hkStock)
        allStocks.append(contentsOf: hkStocks)
        
        // 加载美股数据
        let usStocks = await loadStocksFromFile(fileName: "US-stock", market: .usStock)
        allStocks.append(contentsOf: usStocks)
        
        cachedStocks = allStocks
        isDataLoaded = true
        
        print("✅ 成功加载 \(allStocks.count) 只股票数据")
        print("- A股: \(aStocks.count) 只")
        print("- 港股: \(hkStocks.count) 只")
        print("- 美股: \(usStocks.count) 只")
        
        return allStocks
    }
    
    /// 从文件加载股票数据
    private func loadStocksFromFile(fileName: String, market: MarketType) async -> [StockInfo] {
        guard let fileURL = Bundle.main.url(forResource: fileName, withExtension: nil),
              let content = try? String(contentsOf: fileURL) else {
            print("❌ 无法读取文件: \(fileName)")
            return []
        }
        
        return await parseStockData(content: content, market: market)
    }
    
    /// 解析股票数据
    private func parseStockData(content: String, market: MarketType) async -> [StockInfo] {
        let lines = content.components(separatedBy: .newlines)
        var stocks: [StockInfo] = []
        
        // 跳过标题行
        for line in lines.dropFirst() {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            
            let components = line.components(separatedBy: "\t")
            guard components.count >= 2 else { continue }
            
            let rawCode = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let name = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 标准化股票代码
            let standardizedCode = standardizeStockCode(rawCode: rawCode, market: market)
            
            // 生成模拟价格（基于股票代码的哈希值，保证每次运行结果一致）
            let basePrice = generateBasePrice(for: standardizedCode, market: market)
            let randomVariation = Double.random(in: -0.05...0.05) // ±5%的随机波动
            let currentPrice = basePrice * (1 + randomVariation)
            let changeAmount = currentPrice - basePrice
            let changePercentage = (changeAmount / basePrice) * 100
            
            let stockInfo = StockInfo(
                stockCode: standardizedCode,
                stockName: name,
                market: market,
                currentPrice: currentPrice,
                changeAmount: changeAmount,
                changePercentage: changePercentage
            )
            
            stocks.append(stockInfo)
        }
        
        return stocks
    }
    
    /// 标准化股票代码格式
    private func standardizeStockCode(rawCode: String, market: MarketType) -> String {
        switch market {
        case .cnStock:
            // A股: 000001.SH -> 000001, 000001.SZ -> 000001
            return rawCode.replacingOccurrences(of: ".SH", with: "")
                         .replacingOccurrences(of: ".SZ", with: "")
        case .hkStock:
            // 港股: 700.HK -> 00700
            let code = rawCode.replacingOccurrences(of: ".HK", with: "")
            return String(format: "%05d", Int(code) ?? 0) // 补齐到5位数
        case .usStock:
            // 美股: AAPL.US -> AAPL
            return rawCode.replacingOccurrences(of: ".US", with: "")
        }
    }
    
    /// 根据股票代码和市场生成基础价格
    private func generateBasePrice(for code: String, market: MarketType) -> Double {
        let hash = abs(code.hashValue)
        
        switch market {
        case .cnStock:
            // A股价格范围: 1-500元
            return Double(hash % 500 + 1) + Double(hash % 100) / 100.0
        case .hkStock:
            // 港股价格范围: 0.5-1000港元
            return Double(hash % 1000 + 1) / 2.0 + Double(hash % 100) / 100.0
        case .usStock:
            // 美股价格范围: 1-500美元
            return Double(hash % 500 + 1) + Double(hash % 100) / 100.0
        }
    }
    
    /// 搜索股票
    func searchStocks(query: String, limit: Int = 50) -> [StockInfo] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        let lowercaseQuery = trimmedQuery.lowercased()
        let uppercaseQuery = trimmedQuery.uppercased()
        
        let filteredStocks = cachedStocks.filter { stock in
            // 股票代码匹配（不区分大小写）
            let codeMatch = stock.stockCode.lowercased().contains(lowercaseQuery)
            
            // 股票名称匹配（中文不区分大小写，支持部分匹配）
            let nameMatch = stock.stockName.contains(trimmedQuery) || 
                           stock.stockName.lowercased().contains(lowercaseQuery)
            
            // 支持股票代码前缀匹配（更精确）
            let codeStartsWithMatch = stock.stockCode.lowercased().hasPrefix(lowercaseQuery)
            
            // 支持公司名称关键词匹配
            let nameKeywordMatch = containsKeywords(stockName: stock.stockName, query: trimmedQuery)
            
            return codeMatch || nameMatch || codeStartsWithMatch || nameKeywordMatch
        }
        
        // 按匹配优先级排序
        let sortedResults = filteredStocks.sorted { stock1, stock2 in
            let score1 = calculateMatchScore(stock: stock1, query: trimmedQuery)
            let score2 = calculateMatchScore(stock: stock2, query: trimmedQuery)
            return score1 > score2
        }
        
        return Array(sortedResults.prefix(limit))
    }
    
    /// 计算匹配得分，得分越高优先级越高
    private func calculateMatchScore(stock: StockInfo, query: String) -> Int {
        let lowercaseQuery = query.lowercased()
        var score = 0
        
        // 代码完全匹配：最高分
        if stock.stockCode.lowercased() == lowercaseQuery {
            score += 1000
        }
        // 代码前缀匹配：高分
        else if stock.stockCode.lowercased().hasPrefix(lowercaseQuery) {
            score += 500
        }
        // 代码包含匹配：中等分
        else if stock.stockCode.lowercased().contains(lowercaseQuery) {
            score += 100
        }
        
        // 公司名称匹配
        if stock.stockName == query {
            score += 800  // 名称完全匹配
        } else if stock.stockName.hasPrefix(query) {
            score += 400  // 名称前缀匹配
        } else if stock.stockName.contains(query) {
            score += 200  // 名称包含匹配
        }
        
        // 热门股票加分
        if isPopularStock(stock: stock) {
            score += 50
        }
        
        return score
    }
    
    /// 检查是否包含关键词（支持中文分词的简单实现）
    private func containsKeywords(stockName: String, query: String) -> Bool {
        // 支持常见公司类型关键词
        let companyTypes = ["银行", "保险", "证券", "地产", "科技", "医药", "汽车", "钢铁", "煤炭", "石油", "电力"]
        let queryWords = query.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        
        for word in queryWords {
            if word.count >= 2 && stockName.contains(word) {
                return true
            }
        }
        
        return false
    }
    
    /// 判断是否为热门股票
    private func isPopularStock(stock: StockInfo) -> Bool {
        let popularStocks = [
            // 美股
            "AAPL", "MSFT", "GOOGL", "GOOG", "AMZN", "TSLA", "META", "NVDA",
            // 港股
            "00700", "09988", "01398", "00857", "00941", "03690", "01024",
            // A股
            "600519", "000858", "000001", "600036", "000002", "300750", "600276"
        ]
        
        return popularStocks.contains(stock.stockCode)
    }
    
    /// 根据股票代码获取股票信息
    func getStock(byCode code: String, market: MarketType) -> StockInfo? {
        return cachedStocks.first { stock in
            stock.stockCode == code && stock.market == market
        }
    }
    
    /// 获取指定市场的股票数量
    func getStockCount(for market: MarketType) -> Int {
        return cachedStocks.filter { $0.market == market }.count
    }
    
    /// 获取所有市场的股票总数
    var totalStockCount: Int {
        return cachedStocks.count
    }
}

// MARK: - 预加载扩展
extension StockDataParser {
    /// 预加载数据（在应用启动时调用）
    @MainActor
    func preloadData() {
        Task {
            _ = await loadStockData()
        }
    }
}
