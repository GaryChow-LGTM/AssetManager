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
                    VStack {
                        Image(systemName: "house.fill")
                        Text("首页")
                    }
                }
                .tag(0)
            
            // 分析页 - 深度分析
            AnalysisTabView(assets: portfolioViewModel.assets)
                .tabItem {
                    VStack {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                        Text("分析")
                    }
                }
                .tag(1)
            
            // 我的页 - 设置
            ProfileView()
                .tabItem {
                    VStack {
                        Image(systemName: "person.fill")
                        Text("我的")
                    }
                }
                .tag(2)
        }
        .accentColor(.blue)
        .environmentObject(portfolioViewModel)
        .onAppear {
            // 通过 UITest 启动参数注入示例数据
            if ProcessInfo.processInfo.arguments.contains("-uiTestAddSampleData") {
                portfolioViewModel.addSampleData()
            }
        }
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
