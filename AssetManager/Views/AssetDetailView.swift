import SwiftUI

struct AssetDetailView: View {
    let asset: Asset
    @StateObject private var currencyService = CurrencyService.shared
    @StateObject private var viewModel: AssetDetailViewModel
    
    init(asset: Asset) {
        self.asset = asset
        _viewModel = StateObject(wrappedValue: AssetDetailViewModel(stockCode: asset.stockCode, market: asset.market, currency: asset.currency))
    }
    
    var body: some View {
        List {
            headerSection
            filterSection
            summarySection
            transactionsSection
        }
        .navigationTitle("\(asset.stockName)")
        #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: viewModel.filterType) { _ in viewModel.load() }
        .onChange(of: viewModel.timeRange) { _ in viewModel.load() }
    }
    
    private var headerSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(asset.stockName).font(.headline).fontWeight(.semibold)
                        Text("\(asset.stockCode)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.appCardBackground)
                            .cornerRadius(4)
                        Text(asset.market.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(colorForMarket(asset.market).opacity(0.2))
                            .foregroundColor(colorForMarket(asset.market))
                            .cornerRadius(3)
                    }
                    Text("持仓: \(String(format: "%.0f", asset.shares))股  成本: \(asset.currencyFormattedCostPrice)  当前价: \(asset.currencyFormattedCurrentPrice)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }
    
    private var filterSection: some View {
        Section {
            HStack {
                Picker("类型", selection: $viewModel.filterType) {
                    Text("全部").tag(TransactionType?.none)
                    ForEach(TransactionType.allCases) { t in
                        Text(t.displayName).tag(TransactionType?.some(t))
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            HStack {
                Picker("时间", selection: $viewModel.timeRange) {
                    ForEach(TimeRangeFilter.allCases) { r in
                        Text(r.displayName).tag(r)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
    }
    
    private var summarySection: some View {
        Section("摘要") {
            HStack {
                Text("累计买入")
                Spacer()
                Text(currencyService.formatAmount(viewModel.totalBuyAmount, currency: asset.currency)).fontWeight(.medium)
            }
            HStack {
                Text("累计卖出")
                Spacer()
                Text(currencyService.formatAmount(viewModel.totalSellAmount, currency: asset.currency)).fontWeight(.medium)
            }
            HStack {
                Text("累计已实现盈亏")
                Spacer()
                let pl = viewModel.totalRealizedPL
                let symbol = pl >= 0 ? "+" : ""
                Text("\(symbol)\(currencyService.formatAmount(abs(pl), currency: asset.currency))")
                    .foregroundColor(pl >= 0 ? .green : .red)
                    .fontWeight(.medium)
            }
        }
    }
    
    private var transactionsSection: some View {
        Section("交易") {
            if viewModel.transactions.isEmpty {
                Text("暂无交易记录").foregroundColor(.secondary)
            } else {
                ForEach(viewModel.transactions) { tx in
                    TransactionRow(tx: tx)
                }
            }
        }
    }
    
    private func colorForMarket(_ market: MarketType) -> Color {
        switch market { case .usStock: return .blue; case .hkStock: return .green; case .cnStock: return .red }
    }
}

private struct TransactionRow: View {
    let tx: Transaction
    @StateObject private var currencyService = CurrencyService.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(tx.type.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(tx.type == .buy ? .blue : .orange)
                    Text(formatDate(tx.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text("\(String(format: "%.0f", tx.shares)) 股 @ \(currencyService.formatAmount(tx.price, currency: tx.currency))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if tx.fees > 0 {
                    Text("费用: \(currencyService.formatAmount(tx.fees, currency: tx.currency))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(currencyService.formatAmount(tx.amount, currency: tx.currency))
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let pl = tx.realizedProfitLoss {
                    let symbol = pl >= 0 ? "+" : ""
                    Text("\(symbol)\(currencyService.formatAmount(abs(pl), currency: tx.currency))")
                        .font(.caption)
                        .foregroundColor(pl >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }
}


