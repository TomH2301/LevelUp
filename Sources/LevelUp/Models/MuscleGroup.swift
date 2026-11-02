import Foundation

enum MuscleGroup: String, CaseIterable, Codable, Identifiable {
    case chest = "Brust"
    case triceps = "Trizeps"
    case frontDelts = "Vordere Schulter"
    case sideDelts = "Seitliche Schulter"
    case rearDelts = "Hintere Schulter"
    case back = "Rücken"
    case biceps = "Bizeps"
    case quads = "Quadrizeps"
    case hamstrings = "Hamstrings"
    case glutes = "Gesäß"
    case calves = "Waden"
    case core = "Bauch"
    case forearms = "Unterarme"

    var id: String { rawValue }
    var displayName: String { rawValue }
}
