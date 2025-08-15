import Foundation

struct PortfolioGroup: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var colorHex: String?
    var sortOrder: Int
    
    init(id: String = UUID().uuidString, name: String, colorHex: String? = nil, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }
}


