import SwiftUI

/// 添加资产视图
struct AddAssetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddAssetViewModel()
    
    let onAssetAdded: (Asset) -> Void
    
    // MARK: - Form States
    @State private var searchText = ""
    @State private var selectedStock: StockInfo?
    @State private var selectedCurrency: CurrencyType?
    @State private var shares = ""
    @State private var costPrice = ""
    @State private var purchaseDate = Date()
    @State private var showingStockSelection = false
    
    var body: some View {
        NavigationView {
            Form {
                // 股票选择部分
                stockSelectionSection
                
                // 货币选择部分
                if selectedStock != nil {
                    currencySelectionSection
                }
                
                // 持仓信息输入部分
                if selectedStock != nil && selectedCurrency != nil {
                    positionInfoSection
                }
            }
            .navigationTitle("添加资产")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if canImport(UIKit)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        addAsset()
                    }
                    .disabled(!canAddAsset)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        addAsset()
                    }
                    .disabled(!canAddAsset)
                }
                #endif
            }
            .sheet(isPresented: $showingStockSelection) {
                StockSearchView(onStockSelected: { stock in
                    selectedStock = stock
                    // 设置默认货币
                    selectedCurrency = CurrencyService.shared.getDefaultCurrency(for: stock.market)
                    showingStockSelection = false
                })
            }
            .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("确定") {
                    viewModel.clearError()
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    // MARK: - Stock Selection Section
    private var stockSelectionSection: some View {
        Section {
            Button {
                showingStockSelection = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("选择股票")
                            .foregroundColor(.primary)
                        
                        if let stock = selectedStock {
                            Text("\(stock.stockName) (\(stock.stockCode))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("点击搜索并选择股票")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if let stock = selectedStock {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("¥\(String(format: "%.2f", stock.currentPrice))")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack(spacing: 2) {
                                Image(systemName: stock.isPositive ? "arrow.up.right" : "arrow.down.right")
                                    .font(.caption2)
                                
                                Text(String(format: "%+.2f%%", stock.changePercentage))
                                    .font(.caption2)
                            }
                            .foregroundColor(stock.isPositive ? .green : .red)
                        }
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        } header: {
            Text("股票信息")
        }
    }
    
    // MARK: - Currency Selection Section
    private var currencySelectionSection: some View {
        Section {
            ForEach(CurrencyType.allCases, id: \.self) { currency in
                Button {
                    selectedCurrency = currency
                    HapticFeedback.light()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currency.displayName)
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                            
                            Text(currency.code)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(currency.symbol)
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        if selectedCurrency == currency {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        } header: {
            Text("交易货币")
        } footer: {
            if let selectedStock = selectedStock {
                let defaultCurrency = CurrencyService.shared.getDefaultCurrency(for: selectedStock.market)
                Text("推荐使用 \(defaultCurrency.displayName)(\(defaultCurrency.code))，这是 \(selectedStock.market.displayName) 的常用货币")
            }
        }
    }
    
    // MARK: - Position Info Section
    private var positionInfoSection: some View {
        Section {
            // 持股数量
            HStack {
                Text("持股数量")
                    .foregroundColor(.primary)
                
                Spacer()
                
                TextField("0", text: $shares)
                    #if canImport(UIKit)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                
                Text("股")
                    .foregroundColor(.secondary)
            }
            
            // 平均成本价
            HStack {
                Text("平均成本价")
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("¥")
                    .foregroundColor(.secondary)
                
                TextField("0.00", text: $costPrice)
                    #if canImport(UIKit)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
            
            // 购入时间
            DatePicker(
                "购入时间",
                selection: $purchaseDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .foregroundColor(.primary)
            
            // 预览信息
            if let stock = selectedStock,
               let currency = selectedCurrency,
               let sharesValue = Double(shares),
               let costPriceValue = Double(costPrice),
               sharesValue > 0 && costPriceValue > 0 {
                
                VStack(spacing: 8) {
                    Divider()
                    
                    HStack {
                        Text("总成本")
                        Spacer()
                        Text(CurrencyService.shared.formatAmount(sharesValue * costPriceValue, currency: currency))
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("当前市值")
                        Spacer()
                        Text(CurrencyService.shared.formatAmount(sharesValue * stock.currentPrice, currency: currency))
                            .fontWeight(.medium)
                    }
                    
                    let profitLoss = (sharesValue * stock.currentPrice) - (sharesValue * costPriceValue)
                    let profitLossPercentage = (profitLoss / (sharesValue * costPriceValue)) * 100
                    
                    HStack {
                        Text("预计盈亏")
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            let symbol = profitLoss >= 0 ? "+" : ""
                            Text("\(symbol)\(CurrencyService.shared.formatAmount(abs(profitLoss), currency: currency))")
                                .fontWeight(.medium)
                                .foregroundColor(profitLoss >= 0 ? .green : .red)
                            
                            Text(String(format: "%+.2f%%", profitLossPercentage))
                                .font(.caption)
                                .foregroundColor(profitLoss >= 0 ? .green : .red)
                        }
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
        } header: {
            Text("持仓信息")
        } footer: {
            Text("请输入您的实际持股数量和平均买入成本价格")
        }
    }
    
    // MARK: - Computed Properties
    private var canAddAsset: Bool {
        guard let _ = selectedStock,
              let _ = selectedCurrency,
              let sharesValue = Double(shares),
              let costPriceValue = Double(costPrice) else {
            return false
        }
        
        return sharesValue > 0 && costPriceValue > 0
    }
    
    // MARK: - Actions
    private func addAsset() {
        guard let stock = selectedStock,
              let currency = selectedCurrency,
              let sharesValue = Double(shares),
              let costPriceValue = Double(costPrice) else {
            return
        }
        
        let asset = Asset(
            stockCode: stock.stockCode,
            stockName: stock.stockName,
            market: stock.market,
            currency: currency,
            shares: sharesValue,
            costPrice: costPriceValue,
            currentPrice: stock.currentPrice,
            purchaseDate: purchaseDate
        )
        
        onAssetAdded(asset)
        dismiss()
    }
}

// MARK: - Stock Search View
struct StockSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddAssetViewModel()
    @State private var searchText = ""
    
    let onStockSelected: (StockInfo) -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                // 搜索栏
                searchBar
                
                // 搜索结果
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.searchResults.isEmpty && !searchText.isEmpty {
                    emptyResultsView
                } else {
                    searchResultsList
                }
                
                Spacer()
            }
            .navigationTitle("搜索股票")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if canImport(UIKit)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("输入股票代码或名称", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit {
                    performSearch()
                }
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    viewModel.clearResults()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(10)
        .padding()
        .onChange(of: searchText) { newValue in
            if newValue.isEmpty {
                viewModel.clearResults()
            } else if newValue.count >= 2 {
                // 延迟搜索，避免过于频繁的请求
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if searchText == newValue {
                        performSearch()
                    }
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("搜索中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("未找到相关股票")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("请尝试其他关键词或股票代码")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var searchResultsList: some View {
        List(viewModel.searchResults) { stock in
            StockSearchResultRow(stock: stock) {
                onStockSelected(stock)
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func performSearch() {
        Task {
            await viewModel.searchStocks(query: searchText)
        }
    }
}

// MARK: - Stock Search Result Row
struct StockSearchResultRow: View {
    let stock: StockInfo
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stock.stockName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(stock.stockCode)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.appCardBackground)
                            .cornerRadius(4)
                        
                        Text(stock.market.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(colorForMarket(stock.market).opacity(0.2))
                            .foregroundColor(colorForMarket(stock.market))
                            .cornerRadius(3)
                        
                        Text(stock.market.exchangeName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("¥\(String(format: "%.2f", stock.currentPrice))")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: stock.isPositive ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                        
                        Text(String(format: "%+.2f%%", stock.changePercentage))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(stock.isPositive ? .green : .red)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func colorForMarket(_ market: MarketType) -> Color {
        switch market {
        case .usStock:
            return .blue
        case .hkStock:
            return .green
        case .cnStock:
            return .red
        }
    }
}

// MARK: - Add Asset ViewModel
@MainActor
class AddAssetViewModel: ObservableObject {
    @Published var searchResults: [StockInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let stockAPIService: StockAPIService = StockAPIManager.shared.service
    
    func searchStocks(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let results = try await stockAPIService.searchStocks(query: query)
            self.searchResults = results
        } catch {
            self.errorMessage = "搜索失败: \(error.localizedDescription)"
            self.searchResults = []
        }
        
        isLoading = false
    }
    
    func clearResults() {
        searchResults = []
        errorMessage = nil
    }
    
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Preview
struct AddAssetView_Previews: PreviewProvider {
    static var previews: some View {
        AddAssetView { asset in
            print("添加资产: \(asset)")
        }
    }
}
