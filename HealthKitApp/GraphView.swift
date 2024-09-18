import SwiftUI

struct GraphView: View {
    @ObservedObject var healthManager: HealthManager
    @AppStorage("dailyGoal") private var dailyGoal = 10000
    @State private var selectedTab = 0

    var body: some View {
        VStack {
            Picker("表示期間", selection: $selectedTab) {
                Text("今日").tag(0)
                Text("今週").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            if selectedTab == 0 {
                DailyStepChart(steps: healthManager.dailySteps, goal: dailyGoal)
            } else {
                WeeklyStepChart(weeklySteps: healthManager.weeklySteps, goal: dailyGoal)
            }
        }
        .padding()
        .onAppear {
            healthManager.fetchDailySteps()
            healthManager.fetchWeeklySteps()
        }
    }
}
