import Foundation
import SwiftData

enum ActivityType: String, CaseIterable, Codable, Identifiable {
    case reading = "Lesen"
    case stretching = "Stretching"
    case cardio = "Cardio"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .reading: return "book.fill"
        case .stretching: return "figure.flexibility"
        case .cardio: return "figure.run"
        }
    }

    var skill: Skill {
        switch self {
        case .reading: return .mind
        case .stretching: return .agility
        case .cardio: return .endurance
        }
    }
}

@Model
final class ActivityLog {
    var type: ActivityType
    var date: Date
    var minutes: Int

    init(type: ActivityType, date: Date = .now, minutes: Int) {
        self.type = type
        self.date = date
        self.minutes = minutes
    }
}

enum SkillXPCalculator {
    static func strengthXP(sessions: [WorkoutSession]) -> Double {
        sessions.flatMap(\.setEntries).reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }

    static func xp(for activityType: ActivityType, logs: [ActivityLog]) -> Double {
        logs.filter { $0.type == activityType }.reduce(0) { $0 + Double($1.minutes) }
    }
}
