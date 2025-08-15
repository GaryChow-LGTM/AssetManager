import Foundation

@MainActor
class AssetsStore {
    static let shared = AssetsStore()
    private let userDefaults = UserDefaults.standard
    private let assetsKey = "SavedAssets"
    private init() {}
    
    func load() -> [Asset] {
        if let data = userDefaults.data(forKey: assetsKey),
           let decoded = try? JSONDecoder().decode([Asset].self, from: data) {
            return decoded
        }
        return []
    }
    
    func save(_ assets: [Asset]) {
        if let encoded = try? JSONEncoder().encode(assets) {
            userDefaults.set(encoded, forKey: assetsKey)
        }
    }
}


