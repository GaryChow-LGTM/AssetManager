import SwiftUI

/// 我的页面 - 设置和个人信息
struct ProfileView: View {
    @StateObject private var currencyService = CurrencyService.shared
    @StateObject private var analysisService = PortfolioAnalysisService.shared
    @State private var showingCurrencySettings = false
    @State private var showingAbout = false
    @State private var showingDataManagement = false
    @State private var showingShareExporter = false
    @State private var exportURL: URL?
    @State private var showingImporter = false
    @State private var importError: String?
    @EnvironmentObject private var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        NavigationView {
            List {
                // 用户信息区域
                userInfoSection
                
                // 货币设置
                currencySection
                
                // 数据管理
                dataManagementSection
                
                // 应用信息
                appInfoSection
            }
            .navigationTitle("我的")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                do {
                    try DataBackupService.shared.import(from: url, mode: .replace, portfolioViewModel: portfolioViewModel)
                    HapticFeedback.success()
                } catch {
                    importError = "导入失败: \(error.localizedDescription)"
                }
            case .failure(let err):
                importError = "选择文件失败: \(err.localizedDescription)"
            }
        }
        .sheet(isPresented: $showingShareExporter) {
            if let exportURL = exportURL {
                ShareLink(item: exportURL) { Text("分享导出文件") }
                    .padding()
            }
        }
        .alert("错误", isPresented: .constant(importError != nil)) {
            Button("确定") { importError = nil }
        } message: {
            if let msg = importError { Text(msg) }
        }
        .sheet(isPresented: $showingCurrencySettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingDataManagement) {
            DataManagementView()
        }
    }
    
    // MARK: - 用户信息区域
    private var userInfoSection: some View {
        Section {
            HStack(spacing: 16) {
                // 头像
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("智投用户")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("管理您的投资组合")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 货币设置区域
    private var currencySection: some View {
        Section(header: Text("货币设置")) {
            // 基准货币设置
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("基准货币")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(currencyService.preferences.baseCurrency.displayName) (\(currencyService.preferences.baseCurrency.symbol))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("设置") {
                    showingCurrencySettings = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.vertical, 4)
            
            // 汇率信息
            VStack(spacing: 8) {
                HStack {
                    Text("当前汇率")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button("更新") {
                        showingCurrencySettings = true
                    }
                    .font(.caption)
                }
                
                VStack(spacing: 4) {
                    ExchangeRateRow(
                        from: "CNY",
                        to: "HKD",
                        rate: currencyService.getExchangeRate(from: .cny, to: .hkd)
                    )
                    
                    ExchangeRateRow(
                        from: "CNY",
                        to: "USD",
                        rate: currencyService.getExchangeRate(from: .cny, to: .usd)
                    )
                }
            }
        }
    }
    
    // MARK: - 数据管理区域
    private var dataManagementSection: some View {
        Section("数据管理") {
            // 快照管理
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("投资组合快照")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(analysisService.snapshots.count) 个历史快照")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("管理") {
                    showingDataManagement = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.vertical, 4)
            
            // 数据导出
            HStack {
                Image(systemName: "square.and.arrow.up.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("数据导出")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("导出投资数据备份")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("导出") { exportData() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.vertical, 4)

            // 数据导入
            HStack {
                Image(systemName: "square.and.arrow.down.fill")
                    .foregroundColor(.purple)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("数据导入")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("从备份文件恢复数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("导入") { showingImporter = true }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - 应用信息区域
    private var appInfoSection: some View {
        Section("应用信息") {
            // 版本信息
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("版本信息")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("智投管家 v1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            
            // 关于我们
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("关于智投管家")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("了解更多应用信息")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("查看") {
                    showingAbout = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.vertical, 4)
            
            // 反馈与支持
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("反馈与支持")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("意见建议和技术支持")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("联系") {
                    contactSupport()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - 辅助方法
    
    private func exportData() {
        do {
            let url = try DataBackupService.shared.exportJSON()
            exportURL = url
            showingShareExporter = true
            HapticFeedback.success()
        } catch {
            importError = "导出失败: \(error.localizedDescription)"
        }
    }
    
    private func contactSupport() {
        // TODO: 实现联系支持功能
        HapticFeedback.light()
    }
}

// MARK: - 支持组件

struct ExchangeRateRow: View {
    let from: String
    let to: String
    let rate: Double
    
    var body: some View {
        HStack {
            Text("\(from) → \(to)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(String(format: "%.4f", rate))
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - 关于页面
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 应用图标和名称
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color.blue.gradient)
                            .frame(width: 80, height: 80)
                            .overlay {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                            }
                        
                        VStack(spacing: 4) {
                            Text("智投管家")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Intelli-Asset")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 应用介绍
                    VStack(alignment: .leading, spacing: 16) {
                        Text("关于应用")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("智投管家是一款专业的投资组合管理应用，帮助您轻松管理全球股票投资，提供实时行情、深度分析和多币种支持。")
                            .font(.body)
                            .lineSpacing(4)
                        
                        Text("主要特性")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(icon: "globe", title: "全球市场", description: "支持A股、港股、美股")
                            FeatureRow(icon: "chart.bar.doc.horizontal", title: "深度分析", description: "专业的投资组合分析报告")
                            FeatureRow(icon: "dollarsign.circle", title: "多币种", description: "CNY、HKD、USD支持")
                            FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "实时数据", description: "股价实时更新和历史追踪")
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("关于智投管家")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if canImport(UIKit)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - 数据管理页面
struct DataManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var analysisService = PortfolioAnalysisService.shared
    @State private var showingClearAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section("快照数据") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("历史快照")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("\(analysisService.snapshots.count) 个快照记录")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !analysisService.snapshots.isEmpty {
                            Button("清除全部", role: .destructive) {
                                showingClearAlert = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                if !analysisService.snapshots.isEmpty {
                    Section("快照列表") {
                        ForEach(analysisService.snapshots.suffix(10).reversed(), id: \.id) { snapshot in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(snapshot.date, style: .date)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Text("\(snapshot.assetSnapshots.count) 项资产")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("总市值: \(String(format: "%.2f", snapshot.totalValue)) \(snapshot.baseCurrency.symbol)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("数据管理")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if canImport(UIKit)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
                #endif
            }
        }
        .alert("清除所有快照", isPresented: $showingClearAlert) {
            Button("取消", role: .cancel) { }
            Button("清除", role: .destructive) {
                analysisService.clearAllSnapshots()
            }
        } message: {
            Text("此操作将删除所有历史快照数据，且无法恢复。确定要继续吗？")
        }
    }
}

// MARK: - Preview
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView().environmentObject(PortfolioViewModel())
    }
}
