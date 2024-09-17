import SwiftUI
import HealthKit

class HealthManager: ObservableObject {
    let healthStore = HKHealthStore()
    @Published var steps: Int = 0
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
                    self.fetchSteps()
                    self.startUpdates()
                } else if let error = error {
                    print("Authorization failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func fetchSteps() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                print("Failed to fetch steps: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                self.steps = Int(sum.doubleValue(for: HKUnit.count()))
            }
        }
        
        healthStore.execute(query)
    }

    func startUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.fetchSteps()
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
                    Label("グラフ", systemImage: "chart.pie")
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
                Text("\(healthManager.steps)")
                    .font(.system(size: 80, weight: .bold))
                Button("更新") {
                    healthManager.fetchSteps()
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
                    .trim(from: 0.0, to: min(CGFloat(healthManager.steps) / CGFloat(dailyGoal), 1.0))
                    .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                    .foregroundColor(Color.blue)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: healthManager.steps)
                
                VStack {
                    Text("\(healthManager.steps)")
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                    Text("歩")
                        .font(.title2)
                }
            }
            .frame(width: 250, height: 250)
            
            Text("目標: \(dailyGoal)歩")
                .font(.headline)
                .padding(.top)
            
            if healthManager.steps >= dailyGoal {
                Text("目標達成おめでとうございます！ 🎉")
                    .font(.headline)
                    .foregroundColor(.green)
                    .padding(.top)
            }
        }
        .padding()
        .onAppear {
            healthManager.fetchSteps()
        }
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
