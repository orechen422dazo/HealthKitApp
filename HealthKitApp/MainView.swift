import SwiftUI

struct MainView: View {
    @ObservedObject var healthManager: HealthManager

    var body: some View {
        VStack {
            if healthManager.isAuthorized {
                Text("今日の歩数")
                    .font(.title)
                Text("\(healthManager.dailySteps)")
                    .font(.system(size: 80, weight: .bold))
                Button("更新") {
                    healthManager.fetchDailySteps()
                    healthManager.fetchWeeklySteps()
                }
                .padding()
            } else {
                Text("HealthKitへのアクセスが必要です")
                Button("アクセスを許可") {
                    healthManager.requestAuthorization()
                }
                .padding()
            }
        }
    }
}
