import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TaskListView()
                .tabItem {
                    Label("Aufgaben", systemImage: "checklist")
                }

            BodyMetricsView()
                .tabItem {
                    Label("Körper", systemImage: "chart.line.uptrend.xyaxis")
                }

            TrainingPlanView()
                .tabItem {
                    Label("Training", systemImage: "dumbbell.fill")
                }

            WorkoutView()
                .tabItem {
                    Label("Workout", systemImage: "play.circle.fill")
                }
        }
    }
}

#Preview {
    ContentView()
}
