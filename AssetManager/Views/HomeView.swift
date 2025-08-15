import SwiftUI
import Charts

/// 首页视图 - 展示基本财务信息和持仓信息
struct HomeView: View {
    @ObservedObject var viewModel: PortfolioViewModel
    @StateObject private var currencyService = CurrencyService.shared
    @State private var showingAddAsset = false
    @State private var showingSettings = false
    @State private var selectedChartType: ChartType = .market

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // 统计卡片区域
                    statisticsSection
                    
                    // 图表区域
                    if !viewModel.assets.isEmpty {
                        chartSection
                    }
                    
                    // 资产列表区域
                    assetsSection
                }
                .padding()
            }
            .navigationTitle("智投管家")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if canImport(UIKit)
                ToolbarItem(placement: .navigationBarLeading) {
                    settingsButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    addAssetButton
                }
                #else
                ToolbarItem(placement: .secondaryAction) {
                    settingsButton
                }
                
                ToolbarItem(placement: .primaryAction) {
                    addAssetButton
                }
                #endif
            }
            .refreshable {
                await viewModel.refreshAllPrices()
            }
        }
        .sheet(isPresented: $showingAddAsset) {
            AddAssetView { asset in
                viewModel.addAsset(asset)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(spacing: 16) {
            // 总资产卡片
            StatisticCard(
                title: "总资产",
                value: viewModel.formattedTotalValue,
                subtitle: "基准货币: \(viewModel.baseCurrency.displayName)",
                color: .blue,
                icon: "chart.line.uptrend.xyaxis"
            )
            
            HStack(spacing: 16) {
                // 累计盈亏卡片
                StatisticCard(
                    title: "累计盈亏",
                    value: viewModel.formattedTotalProfitLoss,
                    subtitle: String(format: "%+.2f%%", viewModel.totalProfitLossPercentage),
                    color: viewModel.isTotalProfitable ? .green : .red,
                    icon: viewModel.isTotalProfitable ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
                )
                
                // 总成本卡片
                StatisticCard(
                    title: "总成本",
                    value: viewModel.formattedTotalCost,
                    subtitle: "\(viewModel.assets.count)只股票",
                    color: .orange,
                    icon: "dollarsign.circle.fill"
                )
            }
        }
    }
    
    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("资产分布")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Picker("图表类型", selection: $selectedChartType) {
                    Text("市场").tag(ChartType.market)
                    Text("货币").tag(ChartType.currency)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 120)
            }
            
            Group {
                switch selectedChartType {
                case .market:
                    marketDistributionChart
                case .currency:
                    currencyDistributionChart
                }
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var marketDistributionChart: some View {
        Chart(viewModel.marketDistribution, id: \.market) { data in
            SectorMark(
                angle: .value("占比", data.percentage),
                innerRadius: .ratio(0.5),
                angularInset: 1.5
            )
            .foregroundStyle(colorForMarket(data.market))
            .opacity(0.8)
        }
        .frame(height: 200)
        .chartBackground { _ in
            VStack {
                Text("市场分布")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var currencyDistributionChart: some View {
        Chart(viewModel.currencyDistribution, id: \.currency) { data in
            SectorMark(
                angle: .value("占比", data.percentage),
                innerRadius: .ratio(0.5),
                angularInset: 1.5
            )
            .foregroundStyle(colorForCurrency(data.currency))
            .opacity(0.8)
        }
        .frame(height: 200)
        .chartBackground { _ in
            VStack {
                Text("货币分布")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Assets Section
    private var assetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("我的持仓")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if viewModel.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if viewModel.assets.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.assets) { asset in
                        AssetRowView(asset: asset) {
                            viewModel.removeAsset(asset)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("还没有添加任何资产")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("点击右上角 + 按钮开始添加您的股票持仓")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("添加第一只股票") {
                showingAddAsset = true
                HapticFeedback.light()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Toolbar Buttons
    private var addAssetButton: some View {
        Button {
            showingAddAsset = true
            HapticFeedback.light()
        } label: {
            Image(systemName: "plus")
        }
    }
    
    private var settingsButton: some View {
        Button {
            showingSettings = true
        } label: {
            Image(systemName: "gearshape")
        }
    }
    
    // MARK: - Helper Methods
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
    
    private func colorForCurrency(_ currency: CurrencyType) -> Color {
        switch currency {
        case .cny:
            return .red
        case .hkd:
            return .green
        case .usd:
            return .blue
        }
    }
}

// MARK: - Supporting Types (使用 SharedComponents 中的定义)

// MARK: - Preview
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(viewModel: PortfolioViewModel())
    }
}
