import SwiftUI

/// 主要标签页视图
struct MainTabView: View {
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 首页 - 财务信息和持仓
            HomeView(viewModel: portfolioViewModel)
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(0)
            
            // 分析页 - 深度分析
            AnalysisTabView(assets: portfolioViewModel.assets)
                .tabItem {
                    Label("分析", systemImage: "chart.bar.doc.horizontal.fill")
                }
                .tag(1)
            
            // 我的页 - 设置
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
