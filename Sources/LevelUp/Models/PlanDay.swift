import Foundation
import SwiftData

@Model
final class PlanDay {
    /// 1 = Sonntag ... 7 = Samstag (Calendar.Component.weekday)
    var weekday: Int
    @Relationship(deleteRule: .cascade, inverse: \PlanExercise.planDay) var exercises: [PlanExercise]
    var plan: TrainingPlan?

    init(weekday: Int, exercises: [PlanExercise] = []) {
        self.weekday = weekday
        self.exercises = exercises
    }
}
