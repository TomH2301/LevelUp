import UIKit
import Vision

/// Schätzt eine Gesichtsbreite aus Foto-Landmarks — eine grobe, proportionale
/// Annäherung (nicht fotorealistisch), die einmalig auf die FaceWide-Blendshape
/// gemappt wird. Siehe BlenderAssets/build_character.py für die Gegenseite.
enum FaceShapeAnalyzer {
    /// 0 = unterdurchschnittlich schmales Gesicht, 1 = sehr breites Gesicht,
    /// 0.5 = durchschnittliche Proportion (Referenzwert ~0,78 Breite/Höhe-Verhältnis).
    static func estimatedFaceWidthWeight(image: UIImage) -> Double? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        guard let face = request.results?.first,
              let contour = face.landmarks?.faceContour else { return nil }

        let points = contour.normalizedPoints
        guard !points.isEmpty else { return nil }

        let xs = points.map { Double($0.x) }
        let ys = points.map { Double($0.y) }
        let width = (xs.max() ?? 0) - (xs.min() ?? 0)
        let height = (ys.max() ?? 0) - (ys.min() ?? 0)
        guard height > 0 else { return nil }

        let ratio = width / height

        // Referenz: ein "durchschnittliches" Gesicht liegt bei ~0,75-0,8 Breite/Höhe.
        // Schmal ~0,65, breit ~0,95 — grobe, aber brauchbare Spannweite.
        let minRatio = 0.65
        let maxRatio = 0.95
        let weight = (ratio - minRatio) / (maxRatio - minRatio)
        return min(max(weight, 0), 1)
    }
}
