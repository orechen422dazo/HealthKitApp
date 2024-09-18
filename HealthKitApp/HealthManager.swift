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
