import Foundation

/// Schätzt KFA und einen Muskelmasse-Proxy aus Größe/Gewicht/Alter/Geschlecht,
/// damit der Avatar ab dem ersten Tag plausibel aussieht — nicht erst, nachdem
/// Wochen an echten Tracking-Daten vorliegen. Echte KFA-Messwerte aus dem
/// Körper-Tab haben in AvatarView immer Vorrang vor dieser Schätzung.
enum BodyCompositionEstimator {
    /// Deurenberg-Formel — Standardansatz vieler Fitness-Apps für eine
    /// KFA-Schätzung aus BMI, Alter und Geschlecht.
    static func estimatedBodyFatPercent(heightCm: Double, weightKg: Double, age: Int, gender: AvatarGender) -> Double {
        let heightM = heightCm / 100
        guard heightM > 0 else { return 20 }
        let bmi = weightKg / (heightM * heightM)
        let genderFactor: Double = gender == .male ? 1.0 : 0.0
        let estimate = 1.20 * bmi + 0.23 * Double(age) - 10.8 * genderFactor - 5.4
        return min(max(estimate, 3), 60)
    }

    /// Fettfreie Masse, auf die Körpergröße normalisiert (ähnlich dem Fat-Free-Mass-Index).
    /// Kein exakter Muskelmasse-Wert (fettfreie Masse enthält auch Knochen/Organe/Wasser),
    /// aber ein solider, sofort verfügbarer Näherungswert für den Muscular-Startzustand.
    static func leanMassIndex(weightKg: Double, bodyFatPercent: Double, heightCm: Double) -> Double {
        let heightM = heightCm / 100
        guard heightM > 0 else { return 18 }
        let leanMassKg = weightKg * (1 - bodyFatPercent / 100)
        return leanMassKg / (heightM * heightM)
    }
}
