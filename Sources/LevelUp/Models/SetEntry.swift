import Foundation
import SwiftData

@Model
final class SetEntry {
    var setNumber: Int
    var weightKg: Double
    var reps: Int
    var exercise: Exercise?
    var session: WorkoutSession?

    init(exercise: Exercise, setNumber: Int, weightKg: Double, reps: Int) {
        self.exercise = exercise
        self.setNumber = setNumber
        self.weightKg = weightKg
        self.reps = reps
    }
}
