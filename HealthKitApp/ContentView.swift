import SwiftUI

struct ContentView: View {
    @StateObject private var healthManager = HealthManager()

    var body: some View {
        TabView {
            MainView(healthManager: healthManager)
                .tabItem {
                    Label("メイン", systemImage: "figure.walk")
                }

            GraphView(healthManager: healthManager)
                .tabItem {
                    Label("グラフ", systemImage: "chart.bar")
                }

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gear")
                }
        }
    }
}
