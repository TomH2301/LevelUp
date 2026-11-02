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
    var minBodyFatPercent: Double
    var maxBodyFatPercent: Double
    var maxStrengthLevel: Int

    init(
        gender: AvatarGender = .female,
        skinColorHex: String = "#D9A77C",
        minBodyFatPercent: Double = 8,
        maxBodyFatPercent: Double = 30,
        maxStrengthLevel: Int = 30
    ) {
        self.gender = gender
        self.skinColorHex = skinColorHex
        self.minBodyFatPercent = minBodyFatPercent
        self.maxBodyFatPercent = maxBodyFatPercent
        self.maxStrengthLevel = maxStrengthLevel
    }
}
