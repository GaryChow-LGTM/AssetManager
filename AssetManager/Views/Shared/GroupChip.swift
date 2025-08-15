import SwiftUI

struct GroupChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color.appCardBackground)
                .foregroundColor(isSelected ? .accentColor : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}


