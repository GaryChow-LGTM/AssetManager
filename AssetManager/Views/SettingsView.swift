import SwiftUI

/// 用户设置页面
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var currencyService = CurrencyService.shared
    @State private var showingExchangeRateSettings = false
    
    var body: some View {
        NavigationView {
            List {
                // 基准货币设置
                baseCurrencySection
                
                // 汇率设置
                exchangeRateSection
                
                // 关于信息
                aboutSection
            }
            .navigationTitle("设置")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if canImport(UIKit)
                ToolbarItem(placement: .navigationBarTrailing) {
                    doneButton
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    doneButton
                }
                #endif
            }
            .sheet(isPresented: $showingExchangeRateSettings) {
                ExchangeRateSettingsView()
            }
        }
    }
    
    // MARK: - 基准货币设置
    private var baseCurrencySection: some View {
        Section {
            ForEach(CurrencyType.allCases, id: \.self) { currency in
                Button {
                    currencyService.updateBaseCurrency(currency)
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
                        
                        if currencyService.preferences.baseCurrency == currency {
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
            Text("基准货币")
        } footer: {
            Text("选择用于统计总资产的基准货币。所有资产将自动转换为此货币进行汇总。")
        }
    }
    
    // MARK: - 汇率设置
    private var exchangeRateSection: some View {
        Section {
            Button {
                showingExchangeRateSettings = true
            } label: {
                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundColor(.blue)
                    
                    Text("管理汇率")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button {
                currencyService.resetExchangeRates()
                HapticFeedback.success()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.orange)
                    
                    Text("重置为默认汇率")
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
        } header: {
            Text("汇率设置")
        } footer: {
            Text("您可以手动设置汇率或重置为默认值。默认汇率仅供参考，实际投资请以真实汇率为准。")
        }
    }
    
    // MARK: - 关于信息
    private var aboutSection: some View {
        Section {
            HStack {
                Text("应用版本")
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("支持的市场")
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("A股、港股、美股")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("支持的货币")
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("CNY、HKD、USD")
                    .foregroundColor(.secondary)
            }
            
        } header: {
            Text("关于")
        }
    }
    
    private var doneButton: some View {
        Button("完成") {
            dismiss()
        }
    }
}

// MARK: - 汇率设置页面
struct ExchangeRateSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var currencyService = CurrencyService.shared
    @State private var editingRates: [String: String] = [:]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(getExchangeRatePairs(), id: \.key) { pair in
                    exchangeRateRow(pair: pair)
                }
            }
            .navigationTitle("汇率设置")
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
                    Button("保存") {
                        saveChanges()
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveChanges()
                        dismiss()
                    }
                }
                #endif
            }
        }
        .onAppear {
            loadCurrentRates()
        }
    }
    
    private func exchangeRateRow(pair: (key: String, from: CurrencyType, to: CurrencyType, rate: Double)) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(pair.from.code) → \(pair.to.code)")
                    .fontWeight(.medium)
                
                Text("\(pair.from.displayName) → \(pair.to.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            TextField("汇率", text: Binding(
                get: { editingRates[pair.key] ?? String(format: "%.4f", pair.rate) },
                set: { editingRates[pair.key] = $0 }
            ))
            .textFieldStyle(RoundedBorderTextFieldStyle())
            #if canImport(UIKit)
            .keyboardType(.decimalPad)
            #endif
            .frame(width: 100)
            .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
    
    private func getExchangeRatePairs() -> [(key: String, from: CurrencyType, to: CurrencyType, rate: Double)] {
        let pairs = currencyService.getAllExchangeRatePairs()
        return pairs.map { pair in
            let key = CurrencyPreferences.rateKey(from: pair.from, to: pair.to)
            return (key: key, from: pair.from, to: pair.to, rate: pair.rate)
        }
    }
    
    private func loadCurrentRates() {
        let pairs = getExchangeRatePairs()
        for pair in pairs {
            editingRates[pair.key] = String(format: "%.4f", pair.rate)
        }
    }
    
    private func saveChanges() {
        for (key, rateString) in editingRates {
            if let rate = Double(rateString), rate > 0 {
                let components = key.components(separatedBy: "_")
                if components.count == 2,
                   let fromCurrency = CurrencyType(rawValue: components[0]),
                   let toCurrency = CurrencyType(rawValue: components[1]) {
                    currencyService.updateCustomExchangeRate(from: fromCurrency, to: toCurrency, rate: rate)
                }
            }
        }
        HapticFeedback.success()
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
