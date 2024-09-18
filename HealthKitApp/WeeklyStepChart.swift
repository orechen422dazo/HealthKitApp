import SwiftUI

struct WeeklyStepChart: View {
    let weeklySteps: [Date: Int]
    let goal: Int

    var body: some View {
        VStack {
            Text("今週の歩数")
                .font(.title)
            
            TabView {
                ForEach(getWeekDays(), id: \.self) { date in
                    DailyStepChart(steps: weeklySteps[date] ?? 0, goal: goal)
                        .tabItem {
                            Text(formatDate(date))
                        }
                }
            }
            .frame(height: 350)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
        }
    }

    private func getWeekDays() -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: weekStart)! }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d (E)"
        return formatter.string(from: date)
    }
}
