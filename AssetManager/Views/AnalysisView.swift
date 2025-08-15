import SwiftUI
import Charts

/// 投资组合深度分析页面
struct AnalysisView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var analysisService = PortfolioAnalysisService.shared
    @StateObject private var currencyService = CurrencyService.shared
    @State private var selectedTab: AnalysisTab = .overview
    @State private var selectedTimeRange: TimeRange = .month
    
    let assets: [Asset]
    
    var body: some View {
        NavigationView {
            VStack {
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
            }
            .navigationTitle("深度分析")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if canImport(UIKit)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("快照") {
                        createSnapshot()
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
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

// MARK: - 支持组件

enum AnalysisTab: String, CaseIterable {
    case overview = "总览"
    case distribution = "分布"
    case history = "历史"
    case report = "报告"
    
    var title: String {
        return rawValue
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct ProfitLossRow: View {
    let item: ProfitLossItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.stockName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(item.stockCode)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%+.2f%%", item.profitLossPercentage))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(item.isProfitable ? .green : .red)
                    
                    Text("\(item.currency.symbol)\(String(format: "%.2f", abs(item.profitLoss)))")
                        .font(.caption)
                        .foregroundColor(item.isProfitable ? .green : .red)
                }
            }
            
            HStack {
                Text(item.industry.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
                
                Text(item.market.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                Text("\(String(format: "%.0f", item.shares))股")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.appBackground)
        .cornerRadius(8)
    }
}

// MARK: - Preview
struct AnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        AnalysisView(assets: [])
    }
}
