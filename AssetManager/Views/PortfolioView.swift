import SwiftUI
import Charts

/// 资产组合主页视图
struct PortfolioView: View {
    @StateObject private var viewModel = PortfolioViewModel()
    @State private var showingAddAsset = false
    @State private var selectedChartType: ChartType = .market
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // 顶部统计卡片
                    statisticsSection
                    
                    // 图表区域
                    if !viewModel.assets.isEmpty {
                        chartSection
                    }
                    
                    // 资产列表
                    assetListSection
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
                    refreshButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    addButton
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    addButton
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    refreshButton
                }
                #endif
            }
            .sheet(isPresented: $showingAddAsset) {
                AddAssetView { asset in
                    viewModel.addAsset(asset)
                }
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
            .task {
                if viewModel.assets.isEmpty {
                    // 首次启动时添加示例数据
                    viewModel.addSampleData()
                }
                await viewModel.refreshAllPrices()
            }
        }
    }
    
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(spacing: 16) {
            // 总资产卡片
            StatisticCard(
                title: "总资产",
                value: String(format: "¥%.2f", viewModel.totalValue),
                subtitle: "",
                color: .blue,
                icon: "chart.line.uptrend.xyaxis"
            )
            
            HStack(spacing: 16) {
                // 累计盈亏卡片
                StatisticCard(
                    title: "累计盈亏",
                    value: String(format: "%+.2f", viewModel.totalProfitLoss),
                    subtitle: String(format: "%+.2f%%", viewModel.totalProfitLossPercentage),
                    color: viewModel.isTotalProfitable ? .green : .red,
                    icon: viewModel.isTotalProfitable ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
                )
                
                // 总成本卡片
                StatisticCard(
                    title: "总成本",
                    value: String(format: "¥%.2f", viewModel.totalCost),
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
                Text("投资分布")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Picker("图表类型", selection: $selectedChartType) {
                    Text("市场").tag(ChartType.market)
                    Text("个股").tag(ChartType.stock)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 120)
            }
            
            chartView
                .frame(height: 200)
        }
        .padding()
        .background(Color.appBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    @ViewBuilder
    private var chartView: some View {
        switch selectedChartType {
        case .market:
            marketDistributionChart
        case .stock:
            stockDistributionChart
        }
    }
    
    private var marketDistributionChart: some View {
        Chart(viewModel.marketDistribution, id: \.market) { data in
            SectorMark(
                angle: .value("市值", data.value),
                innerRadius: .ratio(0.5),
                angularInset: 1.5
            )
            .foregroundStyle(colorForMarket(data.market))
            .opacity(0.8)
        }
        .overlay(
            VStack {
                Text("市场分布")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "¥%.0f", viewModel.totalValue))
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        )
    }
    
    private var stockDistributionChart: some View {
        Chart(viewModel.stockDistribution.prefix(8), id: \.asset.id) { data in
            SectorMark(
                angle: .value("持仓比例", data.percentage),
                innerRadius: .ratio(0.5),
                angularInset: 1.5
            )
            .foregroundStyle(colorForStock(data.asset))
            .opacity(0.8)
        }
        .overlay(
            VStack {
                Text("个股分布")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("前8大持仓")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        )
    }
    
    // MARK: - Asset List Section
    private var assetListSection: some View {
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
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.assets) { asset in
                        AssetRowView(asset: asset) {
                            viewModel.removeAsset(asset)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.appBackground)
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
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 32)
    }
    
    // MARK: - Toolbar Buttons
    private var refreshButton: some View {
        Button {
            viewModel.manualRefresh()
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(viewModel.isRefreshing)
    }
    
    private var addButton: some View {
        Button {
            showingAddAsset = true
        } label: {
            Image(systemName: "plus")
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
    
    private func colorForStock(_ asset: Asset) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .yellow, .indigo, .mint]
        let index = abs(asset.stockCode.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Chart Type Enum
enum ChartType {
    case market
    case stock
}

// MARK: - Statistic Card
struct StatisticCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
        }
        .padding()
        .background(Color.appBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Asset Row View
struct AssetRowView: View {
    let asset: Asset
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(asset.stockName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(asset.stockCode)
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
                
                HStack {
                    Text("持仓: \(String(format: "%.0f", asset.shares))股")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("成本: ¥\(String(format: "%.2f", asset.costPrice))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("¥\(String(format: "%.2f", asset.currentValue))")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 4) {
                    Image(systemName: asset.isProfitable ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                    
                    Text(String(format: "%+.2f%%", asset.profitLossPercentage))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(asset.isProfitable ? .green : .red)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(8)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("删除", role: .destructive) {
                onDelete()
            }
        }
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

// MARK: - Preview
struct PortfolioView_Previews: PreviewProvider {
    static var previews: some View {
        PortfolioView()
    }
}
