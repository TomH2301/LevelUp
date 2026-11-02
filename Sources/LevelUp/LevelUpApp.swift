import SwiftUI
import SwiftData

@main
struct LevelUpApp: App {
    init() {
        NotificationManager.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            TaskItem.self,
            BodyMetricEntry.self,
            Exercise.self,
            TrainingPlan.self,
            PlanDay.self,
            PlanExercise.self,
            WorkoutSession.self,
            SetEntry.self
        ])
    }
}
