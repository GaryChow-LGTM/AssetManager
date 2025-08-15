import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Double Extensions
extension Double {
    /// 格式化为货币字符串
    func toCurrencyString(symbol: String = "¥") -> String {
        return "\(symbol)\(String(format: "%.2f", self))"
    }
    
    /// 格式化为百分比字符串
    func toPercentageString(withSign: Bool = true) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        if withSign {
            formatter.positivePrefix = "+"
        }
        
        return formatter.string(from: NSNumber(value: self / 100)) ?? "0.00%"
    }
    
    /// 格式化为带符号的数字字符串
    func toSignedString() -> String {
        return String(format: "%+.2f", self)
    }
}

// MARK: - String Extensions
extension String {
    /// 移除所有空白字符
    func trimmed() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 验证是否为有效的数字
    var isValidNumber: Bool {
        return Double(self) != nil
    }
    
    /// 验证是否为有效的股票代码
    var isValidStockCode: Bool {
        let trimmed = self.trimmed()
        return !trimmed.isEmpty && trimmed.count >= 1 && trimmed.count <= 10
    }
}

// MARK: - Date Extensions
extension Date {
    /// 格式化为简短日期字符串
    func toShortDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: self)
    }
    
    /// 格式化为相对时间字符串（如：2小时前）
    func toRelativeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Color Extensions
extension Color {
    /// 获取市场主题色
    static func marketColor(for market: MarketType) -> Color {
        switch market {
        case .usStock:
            return .blue
        case .hkStock:
            return .green
        case .cnStock:
            return .red
        }
    }
    
    /// 根据盈亏情况获取颜色
    static func profitLossColor(isProfit: Bool) -> Color {
        return isProfit ? .green : .red
    }
    
    /// 应用主题色
    static let appPrimary = Color.blue
    static let appSecondary = Color.gray
    
    #if canImport(UIKit)
    static let appBackground = Color(UIColor.systemBackground)
    static let appCardBackground = Color(UIColor.systemGray6)
    #else
    static let appBackground = Color(NSColor.controlBackgroundColor)
    static let appCardBackground = Color(NSColor.controlColor)
    #endif
}

// MARK: - View Extensions
extension View {
    /// 添加卡片样式
    func cardStyle() -> some View {
        self
            .background(Color.appCardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    /// 添加列表行样式
    func listRowStyle() -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
    
    /// 隐藏键盘
    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

// MARK: - Number Formatters
struct NumberFormatters {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    static let percentage: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

// MARK: - App Constants
struct AppConstants {
    // API相关
    static let apiTimeout: TimeInterval = 30.0
    static let refreshInterval: TimeInterval = 60.0
    
    // UI相关
    static let cardCornerRadius: CGFloat = 12.0
    static let defaultPadding: CGFloat = 16.0
    static let smallPadding: CGFloat = 8.0
    
    // 动画相关
    static let defaultAnimation = Animation.easeInOut(duration: 0.3)
    static let springAnimation = Animation.spring(response: 0.6, dampingFraction: 0.8)
    
    // 存储键
    struct StorageKeys {
        static let assets = "SavedAssets"
        static let lastRefreshTime = "LastRefreshTime"
        static let userPreferences = "UserPreferences"
    }
}

// MARK: - Haptic Feedback
struct HapticFeedback {
    static func light() {
        #if canImport(UIKit)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
    }
    
    static func medium() {
        #if canImport(UIKit)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        #endif
    }
    
    static func heavy() {
        #if canImport(UIKit)
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        #endif
    }
    
    static func success() {
        #if canImport(UIKit)
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
        #endif
    }
    
    static func error() {
        #if canImport(UIKit)
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
        #endif
    }
}
