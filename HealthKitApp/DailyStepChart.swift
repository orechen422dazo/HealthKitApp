import SwiftUI

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
