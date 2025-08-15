import SwiftUI
import Charts

// MARK: - Shared Enums

/// 图表类型枚举
enum ChartType {
    case market
    case currency
}

/// 分析页面标签类型
enum AnalysisTab: String, CaseIterable {
    case overview = "overview"
    case distribution = "distribution" 
    case history = "history"
    case report = "report"
    
    var title: String {
        switch self {
        case .overview:
            return "总览"
        case .distribution:
            return "分布"
        case .history:
            return "历史"
        case .report:
            return "报告"
        }
    }
}

/// 时间范围枚举
enum TimeRange: String, CaseIterable {
    case week = "7天"
    case month = "1个月"
    case quarter = "3个月"
    case halfYear = "6个月"
    case year = "1年"
    case all = "全部"
    
    var days: Int {
        switch self {
        case .week:
            return 7
        case .month:
            return 30
        case .quarter:
            return 90
        case .halfYear:
            return 180
        case .year:
            return 365
        case .all:
            return Int.max
        }
    }
    
    var displayName: String {
        return rawValue
    }
}

// MARK: - Shared Components

/// 通用统计卡片组件
struct StatisticCard: View {
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
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

/// 指标卡片组件（用于分析页面）
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
                    .font(.title3)
                
                Spacer()
            }
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
                .fontWeight(.medium)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCardBackground)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

/// 统计行组件
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

/// 盈亏报告行组件
struct ProfitLossRow: View {
    let item: ProfitLossItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.stockName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(item.stockCode)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f", item.profitLoss))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(item.profitLoss >= 0 ? .green : .red)
                
                Text(String(format: "%+.2f%%", item.profitLossPercentage))
                    .font(.caption)
                    .foregroundColor(item.profitLoss >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Data Types

/// 盈亏报告项目
struct ProfitLossItem: Identifiable {
    let id = UUID()
    let stockCode: String
    let stockName: String
    let market: MarketType
    let industry: IndustryType
    let shares: Double
    let costPrice: Double
    let currentPrice: Double
    let profitLoss: Double
    let profitLossPercentage: Double
    let currency: CurrencyType
    
    var isProfitable: Bool {
        profitLoss >= 0
    }
}
