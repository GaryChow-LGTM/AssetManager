//
//  AssetManagerApp.swift
//  AssetManager
//
//  Created by yimin.cao on 2025/8/15.
//

import SwiftUI

@main
struct AssetManagerApp: App {
    
    init() {
        // 预加载股票数据
        StockDataParser.shared.preloadData()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
