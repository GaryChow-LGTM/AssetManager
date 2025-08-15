import SwiftUI
import Charts

/// 分析页面标签视图
struct AnalysisTabView: View {
    @StateObject private var analysisService = PortfolioAnalysisService.shared
    @StateObject private var currencyService = CurrencyService.shared
    @State private var selectedTab: AnalysisTab = .overview
    @State private var selectedTimeRange: TimeRange = .month
    
    let assets: [Asset]
    
    var body: some View {
        NavigationView {
            VStack {
                // 数据更新状态指示器
                if analysisService.isAnalyzing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("正在更新投资组合分析...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // 标签页选择器
                Picker("分析类型", selection: $selectedTab) {
                    ForEach(AnalysisTab.allCases, id: \.self) { tab in
                        Text(tab.title)
                            .tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // 内容区域
                ScrollView {
                    LazyVStack(spacing: 20) {
                        switch selectedTab {
                        case .overview:
                            overviewSection
                        case .distribution:
                            distributionSection
                        case .history:
                            historySection
                        case .report:
                            reportSection
                        }
                    }
                    .padding()
                }
                .refreshable {
                    // 下拉刷新时更新分析数据
                    await analysisService.createSnapshot(from: assets)
                }
            }
            .navigationTitle("深度分析")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if canImport(UIKit)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("快照") {
                        createSnapshot()
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("快照") {
                        createSnapshot()
                    }
                }
                #endif
            }
        }
        .task {
            await analysisService.createDailySnapshotIfNeeded(from: assets)
        }
        .onAppear {
            // 页面出现时检查是否需要更新分析数据
            Task {
                await analysisService.createSnapshot(from: assets)
            }
        }
    }
    
    // MARK: - 总览页面
    private var overviewSection: some View {
        VStack(spacing: 16) {
            // 关键指标卡片
            keyMetricsCards
            
            // 时间范围选择器
            timeRangeSelector
            
            // 回报率统计
            returnRateCards
        }
    }
    
    private var keyMetricsCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                MetricCard(
                    title: "总资产",
                    value: currencyService.formatAmount(
                        currencyService.calculateTotalValue(assets: assets),
                        currency: currencyService.preferences.baseCurrency
                    ),
                    subtitle: "当前市值",
                    color: .blue,
                    icon: "chart.line.uptrend.xyaxis"
                )
                
                MetricCard(
                    title: "总成本",
                    value: currencyService.formatAmount(
                        currencyService.calculateTotalCost(assets: assets),
                        currency: currencyService.preferences.baseCurrency
                    ),
                    subtitle: "投入资金",
                    color: .orange,
                    icon: "dollarsign.circle"
                )
            }
            
            HStack(spacing: 12) {
                MetricCard(
                    title: "持仓股票",
                    value: "\(assets.count)",
                    subtitle: "只股票",
                    color: .green,
                    icon: "list.bullet"
                )
                
                MetricCard(
                    title: "覆盖市场",
                    value: "\(Set(assets.map { $0.market }).count)",
                    subtitle: "个市场",
                    color: .purple,
                    icon: "globe"
                )
            }
        }
    }
    
    private var timeRangeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("时间范围")
                .font(.headline)
                .fontWeight(.semibold)
            
            Picker("时间范围", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.displayName)
                        .tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(12)
    }
    
    private var returnRateCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                MetricCard(
                    title: "总回报率",
                    value: String(format: "%.2f%%", analysisService.calculateTotalReturn(for: selectedTimeRange)),
                    subtitle: selectedTimeRange.displayName,
                    color: .green,
                    icon: "percent"
                )
                
                MetricCard(
                    title: "年化回报率",
                    value: String(format: "%.2f%%", analysisService.calculateAnnualizedReturn(for: selectedTimeRange)),
                    subtitle: "年化收益",
                    color: .blue,
                    icon: "calendar"
                )
            }
        }
    }
    
    // MARK: - 分布分析页面
    private var distributionSection: some View {
        VStack(spacing: 20) {
            // 市场分布
            marketDistributionCard
            
            // 行业分布
            industryDistributionCard
            
            // 收益来源分布
            profitSourceCard
        }
    }
    
    private var marketDistributionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("市场分布")
                .font(.headline)
                .fontWeight(.semibold)
            
            let marketData = analysisService.getMarketDistribution(from: assets)
            
            if !marketData.isEmpty {
                Chart(marketData, id: \.market) { data in
                    SectorMark(
                        angle: .value("占比", data.percentage),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(colorForMarket(data.market))
                    .opacity(0.8)
                }
                .frame(height: 200)
                
                // 图例
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(marketData, id: \.market) { data in
                        HStack {
                            Circle()
                                .fill(colorForMarket(data.market))
                                .frame(width: 12, height: 12)
                            
                            Text("\(data.market.displayName) (\(String(format: "%.1f%%", data.percentage)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 100)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(12)
    }
    
    private var industryDistributionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("行业分布")
                .font(.headline)
                .fontWeight(.semibold)
            
            let industryData = analysisService.getIndustryDistribution(from: assets)
            
            if !industryData.isEmpty {
                Chart(industryData, id: \.industry) { data in
                    SectorMark(
                        angle: .value("占比", data.percentage),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(colorForIndustry(data.industry))
                    .opacity(0.8)
                }
                .frame(height: 200)
                
                // 图例
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(industryData.prefix(6), id: \.industry) { data in
                        HStack {
                            Circle()
                                .fill(colorForIndustry(data.industry))
                                .frame(width: 12, height: 12)
                            
                            Text("\(data.industry.displayName) (\(String(format: "%.1f%%", data.percentage)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 100)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(12)
    }
    
    private var profitSourceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("收益来源分布")
                .font(.headline)
                .fontWeight(.semibold)
            
            let profitData = analysisService.getProfitSourceDistribution(from: assets)
            
            if !profitData.isEmpty {
                Chart(profitData, id: \.type) { data in
                    BarMark(
                        x: .value("收益", data.value),
                        y: .value("行业", data.type)
                    )
                    .foregroundStyle(.green.gradient)
                }
                .frame(height: max(150, Double(profitData.count) * 30))
            } else {
                Text("暂无盈利数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 100)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - 历史分析页面
    private var historySection: some View {
        VStack(spacing: 20) {
            // 时间范围选择
            timeRangeSelector
            
            // 历史收益曲线
            historyChart
            
            // 历史统计
            historyStats
        }
    }
    
    private var historyChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("历史收益曲线")
                .font(.headline)
                .fontWeight(.semibold)
            
            let historyData = analysisService.getHistoryDataPoints(for: selectedTimeRange)
            
            if !historyData.isEmpty {
                Chart(historyData) { point in
                    LineMark(
                        x: .value("日期", point.date),
                        y: .value("收益率", point.returnRate)
                    )
                    .foregroundStyle(.blue.gradient)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("日期", point.date),
                        y: .value("收益率", point.returnRate)
                    )
                    .foregroundStyle(.blue.gradient.opacity(0.1))
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text("\(String(format: "%.1f", doubleValue))%")
                            }
                        }
                    }
                }
            } else {
                Text("暂无历史数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(12)
    }
    
    private var historyStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("历史统计")
                .font(.headline)
                .fontWeight(.semibold)
            
            let snapshots = analysisService.getSnapshots(for: selectedTimeRange)
            
            if !snapshots.isEmpty {
                let maxValue = snapshots.max { $0.totalValue < $1.totalValue }?.totalValue ?? 0
                let minValue = snapshots.min { $0.totalValue < $1.totalValue }?.totalValue ?? 0
                let avgValue = snapshots.reduce(0) { $0 + $1.totalValue } / Double(snapshots.count)
                
                VStack(spacing: 8) {
                    StatRow(
                        label: "最高市值",
                        value: currencyService.formatAmount(maxValue, currency: currencyService.preferences.baseCurrency)
                    )
                    
                    StatRow(
                        label: "最低市值", 
                        value: currencyService.formatAmount(minValue, currency: currencyService.preferences.baseCurrency)
                    )
                    
                    StatRow(
                        label: "平均市值",
                        value: currencyService.formatAmount(avgValue, currency: currencyService.preferences.baseCurrency)
                    )
                    
                    StatRow(
                        label: "数据点数",
                        value: "\(snapshots.count) 个"
                    )
                }
            } else {
                Text("暂无历史数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - P&L报告页面
    private var reportSection: some View {
        VStack(spacing: 20) {
            // 报告标题
            VStack(alignment: .leading, spacing: 8) {
                Text("盈亏报告")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("详细的盈亏分析和股票表现")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // P&L列表
            profitLossReport
        }
    }
    
    private var profitLossReport: some View {
        VStack(spacing: 8) {
            let reportData = analysisService.generateProfitLossReport(from: assets)
            
            ForEach(reportData) { item in
                ProfitLossRow(item: item)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - 辅助方法
    
    private func createSnapshot() {
        Task {
            await analysisService.createSnapshot(from: assets)
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
    
    private func colorForIndustry(_ industry: IndustryType) -> Color {
        switch industry {
        case .technology:
            return .blue
        case .finance:
            return .green
        case .healthcare:
            return .red
        case .consumer:
            return .orange
        case .energy:
            return .yellow
        case .industrials:
            return .purple
        case .realEstate:
            return .pink
        case .materials:
            return .brown
        case .utilities:
            return .gray
        case .communication:
            return .indigo
        case .other:
            return .mint
        }
    }
}

// MARK: - Preview
struct AnalysisTabView_Previews: PreviewProvider {
    static var previews: some View {
        AnalysisTabView(assets: [])
    }
}
