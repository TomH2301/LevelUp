import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var date: Date
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.session) var setEntries: [SetEntry]

    init(date: Date = .now, setEntries: [SetEntry] = []) {
        self.date = date
        self.setEntries = setEntries
    }
}
