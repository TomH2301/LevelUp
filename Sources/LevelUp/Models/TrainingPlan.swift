import Foundation
import SwiftData

@Model
final class TrainingPlan {
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \PlanDay.plan) var days: [PlanDay]

    init(name: String, days: [PlanDay] = []) {
        self.name = name
        self.days = days
    }
}
