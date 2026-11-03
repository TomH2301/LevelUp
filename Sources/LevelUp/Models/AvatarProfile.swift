import Foundation
import SwiftData

enum AvatarGender: String, CaseIterable, Identifiable, Codable {
    case female = "Weiblich"
    case male = "Männlich"

    var id: String { rawValue }
}

@Model
final class AvatarProfile {
    var gender: AvatarGender
    var skinColorHex: String
    var hairColorHex: String
    var minBodyFatPercent: Double
    var maxBodyFatPercent: Double
    var maxStrengthLevel: Int

    /// Grunddaten fürs Onboarding — ergeben einen plausiblen Avatar ab Tag 1,
    /// statt erst nach Wochen Tracking-Historie. Siehe BodyCompositionEstimator.
    var heightCm: Double
    var age: Int
    /// Nur genutzt, solange noch kein BodyMetricEntry geloggt wurde.
    var fallbackWeightKg: Double
    var minLeanMassIndex: Double
    var maxLeanMassIndex: Double
    /// 0 = Muscular-Achse rein aus Fettfreie-Masse-Schätzung, 1 = rein aus Kraft-Level.
    var trainingInfluence: Double

    /// Gesichtsbreite-Gewicht (0 = schmal/Basis, 1 = volle FaceWide-Form), einmalig
    /// aus der Foto-Kalibrierung berechnet (Vision-Landmarks) — ändert sich nicht
    /// mit Training, anders als Fat/Muscular. Siehe FaceShapeAnalyzer.
    var faceWidthWeight: Double

    init(
        gender: AvatarGender = .female,
        skinColorHex: String = "#D9A77C",
        hairColorHex: String = "#3B2A20",
        minBodyFatPercent: Double = 8,
        maxBodyFatPercent: Double = 30,
        maxStrengthLevel: Int = 30,
        heightCm: Double = 170,
        age: Int = 30,
        fallbackWeightKg: Double = 75,
        minLeanMassIndex: Double = 16,
        maxLeanMassIndex: Double = 24,
        trainingInfluence: Double = 0.5,
        faceWidthWeight: Double = 0.5
    ) {
        self.gender = gender
        self.skinColorHex = skinColorHex
        self.hairColorHex = hairColorHex
        self.minBodyFatPercent = minBodyFatPercent
        self.maxBodyFatPercent = maxBodyFatPercent
        self.maxStrengthLevel = maxStrengthLevel
        self.heightCm = heightCm
        self.age = age
        self.fallbackWeightKg = fallbackWeightKg
        self.minLeanMassIndex = minLeanMassIndex
        self.maxLeanMassIndex = maxLeanMassIndex
        self.trainingInfluence = trainingInfluence
        self.faceWidthWeight = faceWidthWeight
    }
}
