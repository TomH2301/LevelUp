import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            AvatarView()
                .tabItem {
                    Label("Avatar", systemImage: "figure.stand")
                }

            SkillsView()
                .tabItem {
                    Label("Skills", systemImage: "chart.bar.xaxis")
                }

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
