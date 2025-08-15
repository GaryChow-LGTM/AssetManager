import SwiftUI

/// 买入资产视图（用于详情页快速加仓）
struct BuyAssetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var currencyService = CurrencyService.shared
    
    let asset: Asset
    let onConfirm: (_ shares: Double, _ price: Double, _ date: Date, _ fees: Double) -> Void
    
    @State private var sharesText: String = ""
    @State private var priceText: String = ""
    @State private var date: Date = Date()
    @State private var feesText: String = ""
    @State private var localError: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(asset.stockName).fontWeight(.medium)
                            HStack(spacing: 6) {
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
                            Text("当前价: \(asset.currencyFormattedCurrentPrice)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                } header: { Text("标的信息") }
                
                Section {
                    HStack {
                        Text("买入数量")
                        Spacer()
                        TextField("0", text: $sharesText)
                            #if canImport(UIKit)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                        Text("股").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("买入价格")
                        Spacer()
                        Text(asset.currency.symbol).foregroundColor(.secondary)
                        TextField("0.00", text: $priceText)
                            #if canImport(UIKit)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    DatePicker("买入日期", selection: $date, in: ...Date(), displayedComponents: .date)
                    HStack {
                        Text("费用(可选)")
                        Spacer()
                        Text(asset.currency.symbol).foregroundColor(.secondary)
                        TextField("0.00", text: $feesText)
                            #if canImport(UIKit)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                } header: { Text("买入信息") } footer: {
                    Text("费用仅记录到交易，不直接计入成本价；成本价沿用加权平均法")
                }
                
                if canPreview {
                    Section("预估结果") {
                        let shares = Double(sharesText) ?? 0
                        let price = Double(priceText) ?? 0
                        let fees = Double(feesText) ?? 0
                        let total = shares * price + fees
                        HStack {
                            Text("总成本")
                            Spacer()
                            Text(currencyService.formatAmount(total, currency: asset.currency)).fontWeight(.medium)
                        }
                        let newShares = asset.shares + shares
                        HStack {
                            Text("买入后持仓")
                            Spacer()
                            Text("\(String(format: "%.0f", newShares)) 股").foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("买入")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if canImport(UIKit)
                ToolbarItem(placement: .navigationBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("确认买入") { submit() }.disabled(!canSubmit) }
                #else
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("确认买入") { submit() }.disabled(!canSubmit) }
                #endif
            }
            .alert("错误", isPresented: .constant(localError != nil)) { Button("确定") { localError = nil } } message: {
                if let msg = localError { Text(msg) }
            }
            .onAppear { priceText = String(format: "%.2f", asset.currentPrice) }
        }
    }
    
    private var canPreview: Bool { (Double(sharesText) ?? 0) > 0 && (Double(priceText) ?? 0) > 0 }
    private var canSubmit: Bool {
        guard let s = Double(sharesText), let p = Double(priceText) else { return false }
        return s > 0 && p > 0 && (Double(feesText) ?? 0) >= 0
    }
    
    private func submit() {
        guard let s = Double(sharesText), s > 0 else { localError = "请输入有效数量"; return }
        guard let p = Double(priceText), p > 0 else { localError = "请输入有效价格"; return }
        let f = Double(feesText) ?? 0
        guard f >= 0 else { localError = "费用不能为负"; return }
        onConfirm(s, p, date, f)
        dismiss()
    }
    
    private func colorForMarket(_ market: MarketType) -> Color {
        switch market { case .usStock: return .blue; case .hkStock: return .green; case .cnStock: return .red }
    }
}


