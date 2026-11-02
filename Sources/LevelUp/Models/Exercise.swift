import Foundation
import SwiftData

struct MuscleEngagement: Codable, Hashable {
    var muscleGroup: MuscleGroup
    /// Satz-Äquivalente pro ausgeführtem Satz dieser Übung, z.B. Bankdrücken: Brust 1.0, Trizeps 0.5, vordere Schulter 0.5
    var setFactor: Double
}

@Model
final class Exercise {
    var name: String
    var muscleEngagements: [MuscleEngagement]

    init(name: String, muscleEngagements: [MuscleEngagement] = []) {
        self.name = name
        self.muscleEngagements = muscleEngagements
    }
}
