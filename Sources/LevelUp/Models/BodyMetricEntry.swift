import Foundation
import SwiftData

@Model
final class BodyMetricEntry {
    var date: Date
    var weightKg: Double
    var bodyFatPercentage: Double?

    init(date: Date = .now, weightKg: Double, bodyFatPercentage: Double? = nil) {
        self.date = date
        self.weightKg = weightKg
        self.bodyFatPercentage = bodyFatPercentage
    }
}
