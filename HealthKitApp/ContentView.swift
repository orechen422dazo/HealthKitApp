import SwiftUI
import HealthKit

class HealthManager: ObservableObject {
    let healthStore = HKHealthStore()
    @Published var dailySteps: Int = 0
    @Published var weeklySteps: [Date: Int] = [:]
    @Published var isAuthorized = false
    private var updateTimer: Timer?

    init() {
        requestAuthorization()
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }

        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        healthStore.requestAuthorization(toShare: [], read: [stepType]) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if success {
                    self.fetchDailySteps()
                    self.fetchWeeklySteps()
                    self.startUpdates()
                } else if let error = error {
                    print("Authorization failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func fetchDailySteps() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                print("Failed to fetch daily steps: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                self.dailySteps = Int(sum.doubleValue(for: HKUnit.count()))
            }
        }
        
        healthStore.execute(query)
    }

    func fetchWeeklySteps() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfWeek, end: endOfWeek, options: .strictStartDate)
        
        let query = HKStatisticsCollectionQuery(quantityType: stepType,
                                                quantitySamplePredicate: predicate,
                                                options: .cumulativeSum,
                                                anchorDate: startOfWeek,
                                                intervalComponents: DateComponents(day: 1))
        
        query.initialResultsHandler = { query, results, error in
            guard let results = results else {
                print("Failed to fetch weekly steps: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            var steps: [Date: Int] = [:]
            results.enumerateStatistics(from: startOfWeek, to: endOfWeek) { statistics, stop in
                if let quantity = statistics.sumQuantity() {
                    let date = statistics.startDate
                    let value = Int(quantity.doubleValue(for: HKUnit.count()))
                    steps[date] = value
                }
            }
            
            DispatchQueue.main.async {
                self.weeklySteps = steps
            }
        }
        
        healthStore.execute(query)
    }

    func startUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.fetchDailySteps()
            self.fetchWeeklySteps()
        }
    }

    deinit {
        updateTimer?.invalidate()
    }
}

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

struct DailyStepChart: View {
    let steps: Int
    let goal: Int

    var body: some View {
        VStack {
            Text("今日の歩数")
                .font(.title)
            ZStack {
                Circle()
                    .stroke(lineWidth: 20)
                    .opacity(0.3)
                    .foregroundColor(Color.blue)
                
                Circle()
                    .trim(from: 0.0, to: min(CGFloat(steps) / CGFloat(goal), 1.0))
                    .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                    .foregroundColor(Color.blue)
                    .rotationEffect(Angle(degrees: 270.0))
                
                VStack {
                    Text("\(steps)")
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                    Text("歩")
                        .font(.title2)
                }
            }
            .frame(height: 250)
            
            Text("目標: \(goal)歩")
                .font(.headline)
                .padding(.top)
            
            if steps >= goal {
                Text("目標達成おめでとうございます！ 🎉")
                    .font(.headline)
                    .foregroundColor(.green)
                    .padding(.top)
            }
        }
    }
}

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
