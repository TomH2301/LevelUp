import Foundation

enum Skill: String, CaseIterable, Identifiable {
    case strength = "Kraft"
    case mind = "Geist"
    case agility = "Agilität"
    case endurance = "Ausdauer"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .mind: return "book.fill"
        case .agility: return "figure.flexibility"
        case .endurance: return "figure.run"
        }
    }
}

enum LevelCalculator {
    static func level(forXP xp: Double) -> Int {
        var level = 1
        while xpRequired(forLevel: level + 1) <= xp {
            level += 1
        }
        return level
    }

    static func xpRequired(forLevel level: Int) -> Double {
        guard level > 1 else { return 0 }
        return 100 * pow(Double(level - 1), 1.5)
    }

    static func progress(forXP xp: Double) -> (level: Int, currentLevelXP: Double, nextLevelXP: Double) {
        let lvl = level(forXP: xp)
        let currentThreshold = xpRequired(forLevel: lvl)
        let nextThreshold = xpRequired(forLevel: lvl + 1)
        return (lvl, xp - currentThreshold, nextThreshold - currentThreshold)
    }
}
