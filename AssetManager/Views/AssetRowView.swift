import SwiftUI

/// 资产行视图组件
struct AssetRowView: View {
    let asset: Asset
    let onDelete: () -> Void
    var onSell: (() -> Void)? = nil
    
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
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("持仓: \(String(format: "%.0f", asset.shares))股")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("成本: \(asset.formattedCostPrice)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("(\(asset.currency.code))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(colorForCurrency(asset.currency).opacity(0.2))
                            .cornerRadius(2)
                    }
                    
                    Text("购入: \(formatPurchaseDate(asset.purchaseDate))")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(asset.formattedCurrentValue)
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
        .accessibilityIdentifier("AssetRow_\(asset.stockCode)_\(asset.market.rawValue)")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onSell = onSell {
                Button("卖出") {
                    onSell()
                }
                .tint(.blue)
                .accessibilityIdentifier("sell_button")
            }
            Button("删除", role: .destructive) {
                onDelete()
            }
            .accessibilityIdentifier("delete_button")
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if let onSell = onSell {
                Button("卖出") { onSell() }
                    .tint(.blue)
                    .accessibilityIdentifier("sell_button_leading")
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
    
    private func formatPurchaseDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }
}

// MARK: - Preview
struct AssetRowView_Previews: PreviewProvider {
    static var previews: some View {
        AssetRowView(
            asset: Asset(
                stockCode: "AAPL",
                stockName: "苹果公司",
                market: .usStock,
                shares: 100,
                costPrice: 150.0,
                currentPrice: 180.0
            )
        ) {
            // Delete action
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
