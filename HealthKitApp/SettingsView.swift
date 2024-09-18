import SwiftUI

struct SettingsView: View {
    @AppStorage("dailyGoal") private var dailyGoal = 10000

    var body: some View {
        Form {
            Section(header: Text("目標設定")) {
                Stepper("1日の目標歩数: \(dailyGoal)", value: $dailyGoal, in: 1000...50000, step: 1000)
            }
        }
        .navigationTitle("設定")
    }
}
