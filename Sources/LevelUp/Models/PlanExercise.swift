import Foundation
import SwiftData

@Model
final class PlanExercise {
    var targetSets: Int
    var exercise: Exercise?
    var planDay: PlanDay?

    init(exercise: Exercise, targetSets: Int) {
        self.exercise = exercise
        self.targetSets = targetSets
    }
}
