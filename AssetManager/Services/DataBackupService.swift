import Foundation
import SwiftUI

struct BackupBundle: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let appVersion: String
    let currencyPreferences: CurrencyPreferences
    let exchangeRates: [String: Double]
    let groups: [PortfolioGroup]
    let assets: [Asset]
    let transactions: [Transaction]
}

@MainActor
class DataBackupService: ObservableObject {
    static let shared = DataBackupService()
    
    private let assetsStore = AssetsStore.shared
    private let groupStore = GroupStore.shared
    private let txStore = TransactionStore.shared
    private let currencyService = CurrencyService.shared
    
    private init() {}
    
    func exportJSON() throws -> URL {
        let bundle = BackupBundle(
            schemaVersion: 1,
            exportedAt: Date(),
            appVersion: "1.0.0",
            currencyPreferences: currencyService.preferences,
            exchangeRates: currencyService.exchangeRates,
            groups: groupStore.list(),
            assets: assetsStore.load(),
            transactions: txStore.listAll()
        )
        let data = try JSONEncoder().encode(bundle)
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("AssetManager_Backup_\(Int(Date().timeIntervalSince1970)).json")
        try data.write(to: url)
        return url
    }
    
    enum ImportMode { case replace, merge }
    
    func `import`(from url: URL, mode: ImportMode = .replace, portfolioViewModel: PortfolioViewModel) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let bundle = try decoder.decode(BackupBundle.self, from: data)
        
        switch mode {
        case .replace:
            // 覆盖恢复
            restoreReplace(bundle: bundle, portfolioViewModel: portfolioViewModel)
        case .merge:
            restoreMerge(bundle: bundle, portfolioViewModel: portfolioViewModel)
        }
    }
    
    private func restoreReplace(bundle: BackupBundle, portfolioViewModel: PortfolioViewModel) {
        // 写偏好/汇率
        currencyService.preferences = bundle.currencyPreferences
        currencyService.exchangeRates = bundle.exchangeRates
        // 写分组
        groupStore.replaceAll(bundle.groups)
        // 写资产
        assetsStore.save(bundle.assets)
        portfolioViewModel.manualReloadAssets()
        // 写交易
        txStore.replaceAll(bundle.transactions)
        // 重建分析
        Task { await PortfolioAnalysisService.shared.createSnapshot(from: portfolioViewModel.assets) }
    }
    
    private func restoreMerge(bundle: BackupBundle, portfolioViewModel: PortfolioViewModel) {
        // 简化：合并策略（资产按 stockCode+market 合并 shares 与成本；分组并集；交易追加去重）
        var currentAssets = assetsStore.load()
        var map = Dictionary(uniqueKeysWithValues: currentAssets.map { ("\($0.stockCode)_\($0.market.rawValue)", $0) })
        for a in bundle.assets {
            let key = "\(a.stockCode)_\(a.market.rawValue)"
            if var exist = map[key] {
                // 加仓合并（沿用 ViewModel 的加权原则简化重现）
                let totalShares = exist.shares + a.shares
                if totalShares > 0 {
                    let existingTotalCost = exist.shares * exist.costPrice
                    let addedTotalCostOriginal = a.shares * a.costPrice
                    let addedInExisting = a.currency == exist.currency
                        ? addedTotalCostOriginal
                        : CurrencyService.shared.convert(amount: addedTotalCostOriginal, from: a.currency, to: exist.currency)
                    let mergedTotalCost = existingTotalCost + addedInExisting
                    exist.shares = totalShares
                    exist.costPrice = mergedTotalCost / totalShares
                    // 分组以导入优先（若为空则保持现有）
                    if let gid = a.groupId { exist.groupId = gid }
                    map[key] = exist
                }
            } else {
                map[key] = a
            }
        }
        let mergedAssets = Array(map.values)
        assetsStore.save(mergedAssets)
        portfolioViewModel.manualReloadAssets()
        
        // 分组并集
        groupStore.merge(bundle.groups)
        
        // 交易去重（按 id）
        txStore.merge(bundle.transactions)
        
        // 偏好/汇率以导入为准
        currencyService.preferences = bundle.currencyPreferences
        currencyService.exchangeRates = bundle.exchangeRates
        
        Task { await PortfolioAnalysisService.shared.createSnapshot(from: portfolioViewModel.assets) }
    }
}


