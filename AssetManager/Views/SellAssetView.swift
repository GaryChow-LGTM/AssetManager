import SwiftUI

/// 卖出资产视图
struct SellAssetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var currencyService = CurrencyService.shared

    let asset: Asset
    let onSellConfirmed: (_ soldShares: Double, _ sellPrice: Double, _ sellDate: Date, _ fees: Double) -> Void

    // 表单状态
    @State private var soldSharesText: String = ""
    @State private var sellPriceText: String = ""
    @State private var sellDate: Date = Date()
    @State private var feesText: String = ""

    // 错误提示
    @State private var localError: String?

    var body: some View {
        NavigationView {
            Form {
                assetInfoSection
                sellFormSection
                if canPreview { previewSection }
            }
            .navigationTitle("卖出资产")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if canImport(UIKit)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认卖出") { submit() }
                        .disabled(!canSubmit)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认卖出") { submit() }
                        .disabled(!canSubmit)
                }
                #endif
            }
            .alert("错误", isPresented: .constant(localError != nil)) {
                Button("确定") { localError = nil }
            } message: {
                if let msg = localError { Text(msg) }
            }
            .onAppear {
                // 初始化价格为当前价
                sellPriceText = String(format: "%.2f", asset.currentPrice)
            }
        }
    }

    // MARK: - Sections
    private var assetInfoSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.stockName)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
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
                    Text("持仓: \(String(format: "%.0f", asset.shares))股  成本: \(asset.currencyFormattedCostPrice)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(currencyService.formatAmount(asset.currentPrice, currency: asset.currency))
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("当前价")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("标的信息")
        }
    }

    private var sellFormSection: some View {
        Section {
            HStack {
                Text("卖出数量")
                Spacer()
                TextField("0", text: $soldSharesText)
                    #if canImport(UIKit)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                Text("股")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("卖出价格")
                Spacer()
                Text(asset.currency.symbol)
                    .foregroundColor(.secondary)
                TextField("0.00", text: $sellPriceText)
                    #if canImport(UIKit)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }

            DatePicker("卖出日期", selection: $sellDate, in: ...Date(), displayedComponents: .date)

            HStack {
                Text("费用(可选)")
                Spacer()
                Text(asset.currency.symbol)
                    .foregroundColor(.secondary)
                TextField("0.00", text: $feesText)
                    #if canImport(UIKit)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }

        } header: {
            Text("卖出信息")
        } footer: {
            Text("卖出数量需小于等于当前持仓；费用为空按0处理")
        }
    }

    private var previewSection: some View {
        Section {
            let soldShares = Double(soldSharesText) ?? 0
            let sellPrice = Double(sellPriceText) ?? 0
            let fees = Double(feesText) ?? 0
            let proceeds = soldShares * sellPrice
            let cost = soldShares * asset.costPrice
            let realizedPL = proceeds - cost - fees

            HStack {
                Text("成交额")
                Spacer()
                Text(currencyService.formatAmount(proceeds, currency: asset.currency))
                    .fontWeight(.medium)
            }

            HStack {
                Text("预估已实现盈亏")
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    let symbol = realizedPL >= 0 ? "+" : ""
                    Text("\(symbol)\(currencyService.formatAmount(abs(realizedPL), currency: asset.currency))")
                        .foregroundColor(realizedPL >= 0 ? .green : .red)
                        .fontWeight(.medium)
                    Text(String(format: "%+.2f%%", (sellPrice - asset.costPrice) / asset.costPrice * 100))
                        .font(.caption)
                        .foregroundColor(realizedPL >= 0 ? .green : .red)
                }
            }

            let remaining = max(asset.shares - soldShares, 0)
            HStack {
                Text("卖出后剩余持仓")
                Spacer()
                Text("\(String(format: "%.0f", remaining)) 股")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("预估结果")
        }
    }

    // MARK: - Actions
    private func submit() {
        guard let soldShares = Double(soldSharesText), soldShares > 0 else {
            localError = "请输入有效的卖出数量"
            return
        }
        guard let sellPrice = Double(sellPriceText), sellPrice > 0 else {
            localError = "请输入有效的卖出价格"
            return
        }
        let fees = Double(feesText) ?? 0
        guard soldShares <= asset.shares else {
            localError = "卖出数量超过当前持仓"
            return
        }

        onSellConfirmed(soldShares, sellPrice, sellDate, fees)
        dismiss()
    }

    // MARK: - Helpers
    private var canPreview: Bool {
        (Double(soldSharesText) ?? 0) > 0 && (Double(sellPriceText) ?? 0) > 0
    }

    private var canSubmit: Bool {
        guard let sold = Double(soldSharesText), let price = Double(sellPriceText) else { return false }
        return sold > 0 && price > 0 && sold <= asset.shares
    }

    private func colorForMarket(_ market: MarketType) -> Color {
        switch market {
        case .usStock: return .blue
        case .hkStock: return .green
        case .cnStock: return .red
        }
    }
}

// MARK: - Preview
struct SellAssetView_Previews: PreviewProvider {
    static var previews: some View {
        let asset = Asset(
            stockCode: "AAPL",
            stockName: "苹果公司",
            market: .usStock,
            currency: .usd,
            shares: 100,
            costPrice: 150,
            currentPrice: 180
        )
        return SellAssetView(asset: asset) { _, _, _, _ in }
    }
}


