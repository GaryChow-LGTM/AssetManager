import SwiftUI
import Charts

/// 首页视图 - 展示基本财务信息和持仓信息
struct HomeView: View {
    @ObservedObject var viewModel: PortfolioViewModel
    @StateObject private var currencyService = CurrencyService.shared
    @StateObject private var analysisService = PortfolioAnalysisService.shared
    @State private var showingAddAsset = false
    @State private var assetToSell: Asset?
    
    @State private var selectedChartType: ChartType = .market
    @State private var selectedTimeRange: TimeRange = .month
    @State private var showPercentageTrend: Bool = true

    var body: some View {
        NavigationView {
            List {
                // 账户总览
                Section {
                    accountOverviewSection
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 4)
                }

                // 收益趋势
                Section {
                    returnsTrendSection
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 4)
                }

                // 图表区域
                if !viewModel.assets.isEmpty {
                    Section {
                        chartSection
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 4)
                    }
                }

                // 资产列表区域（每个资产为独立行，支持右滑）
                assetsListSection
            }
            .listStyle(PlainListStyle())
            .navigationTitle("智投管家")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if canImport(UIKit)
                ToolbarItem(placement: .navigationBarTrailing) {
                    addAssetButton
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    addAssetButton
                }
                #endif
            }
            .refreshable { await viewModel.refreshAllPrices() }
        }
        .sheet(isPresented: $showingAddAsset) {
            AddAssetView { asset in
                viewModel.addAsset(asset)
            }
        }
        .sheet(item: $assetToSell) { asset in
            SellAssetView(asset: asset) { soldShares, sellPrice, sellDate, fees in
                viewModel.sellAsset(asset, soldShares: soldShares, sellPrice: sellPrice, sellDate: sellDate, fees: fees)
            }
        }
        .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Account Overview Section
    private var accountOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("账户总览")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    StatisticCard(
                        title: "总资产",
                        value: viewModel.formattedTotalValue,
                        subtitle: "基准货币: \(viewModel.baseCurrency.displayName)",
                        color: .blue,
                        icon: "wallet.pass.fill"
                    )
                    StatisticCard(
                        title: "总收益",
                        value: viewModel.formattedTotalProfitLoss,
                        subtitle: String(format: "%+.2f%%", viewModel.totalProfitLossPercentage),
                        color: viewModel.isTotalProfitable ? .green : .red,
                        icon: viewModel.isTotalProfitable ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill"
                    )
                }
                HStack(spacing: 12) {
                    StatisticCard(
                        title: "总收益率",
                        value: String(format: "%+.2f%%", viewModel.totalProfitLossPercentage),
                        subtitle: "基于总成本",
                        color: viewModel.isTotalProfitable ? .green : .red,
                        icon: "percent"
                    )
                    StatisticCard(
                        title: "今日收益",
                        value: formattedTodayProfitLoss,
                        subtitle: todayReferenceText,
                        color: todayProfitLossAmount >= 0 ? .green : .red,
                        icon: todayProfitLossAmount >= 0 ? "sun.max.fill" : "sun.min.fill"
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color.appCardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    // MARK: - Returns Trend Section
    private var returnsTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("收益趋势")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showPercentageTrend.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: showPercentageTrend ? "percent" : "yensign.circle")
                        Text(showPercentageTrend ? "按百分比" : "按金额")
                            .font(.subheadline)
                    }
                }
                .buttonStyle(.bordered)
            }

            // 趋势图
            trendChart

            // 时间范围选择器
            timeRangePicker
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    private var trendChart: some View {
        Group {
            if showPercentageTrend {
                Chart(analysisService.getHistoryDataPoints(for: selectedTimeRange)) { point in
                    LineMark(
                        x: .value("日期", point.date),
                        y: .value("收益率", point.returnRate)
                    )
                    .foregroundStyle(point.returnRate >= 0 ? .green : .red)
                }
                .frame(height: 220)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            } else {
                Chart(analysisService.getSnapshots(for: selectedTimeRange)) { s in
                    LineMark(
                        x: .value("日期", s.date),
                        y: .value("收益额", s.totalProfitLoss)
                    )
                    .foregroundStyle(s.totalProfitLoss >= 0 ? .green : .red)
                }
                .frame(height: 220)
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                .chartYAxis { AxisMarks(position: .leading) }
            }
        }
    }

    private var timeRangePicker: some View {
        HStack {
            ForEach([TimeRange.week, .month, .quarter, .year, .all], id: \.self) { range in
                Button(action: { selectedTimeRange = range }) {
                    Text(range.displayName)
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedTimeRange == range ? Color.accentColor.opacity(0.15) : Color.clear)
                        .foregroundColor(selectedTimeRange == range ? .accentColor : .primary)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Today PL helpers
    private var todayProfitLossAmount: Double {
        let today = Calendar.current.startOfDay(for: Date())
        let todays = analysisService.snapshots.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        guard let first = todays.first, let last = todays.last else { return 0 }
        return last.totalProfitLoss - first.totalProfitLoss
    }

    private var formattedTodayProfitLoss: String {
        let amount = todayProfitLossAmount
        let symbol = amount >= 0 ? "+" : ""
        return symbol + currencyService.formatAmount(abs(amount), currency: viewModel.baseCurrency)
    }

    private var todayReferenceText: String {
        let today = Calendar.current.startOfDay(for: Date())
        let count = analysisService.snapshots.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }.count
        if count >= 2 { return "相对今日开盘" }
        return "缺少今日参考快照"
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
    private var assetsListSection: some View {
        Section(header:
                    HStack {
                        Text("我的持仓")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        if viewModel.isRefreshing { ProgressView().scaleEffect(0.8) }
                    }
        ) {
            if viewModel.assets.isEmpty {
                emptyStateView
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.assets) { asset in
                    NavigationLink(destination: AssetDetailView(asset: asset)) {
                        AssetRowView(asset: asset) {
                            viewModel.removeAsset(asset)
                        } onSell: {
                            assetToSell = asset
                            HapticFeedback.light()
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 4)
                }
            }
        }
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
