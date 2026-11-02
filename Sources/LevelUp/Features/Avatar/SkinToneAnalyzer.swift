import UIKit
import Vision
import CoreImage

/// Schätzt Hautton und Haarfarbe aus einem Foto, rein zur Avatar-Farbkalibrierung
/// — kein fotorealistischer Nachbau, nur zwei Durchschnittsfarben.
enum SkinToneAnalyzer {
    static func analyze(image: UIImage) -> (skin: String, hair: String)? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        guard let face = request.results?.first else { return nil }

        // Vision-Normalkoordinaten und CIImage-Koordinaten haben beide den
        // Ursprung unten links — direkt skalierbar ohne Flip.
        let box = face.boundingBox
        let faceRect = CGRect(
            x: extent.minX + box.minX * extent.width,
            y: extent.minY + box.minY * extent.height,
            width: box.width * extent.width,
            height: box.height * extent.height
        )

        let skinRect = CGRect(
            x: faceRect.midX - faceRect.width * 0.15,
            y: faceRect.minY + faceRect.height * 0.15,
            width: faceRect.width * 0.3,
            height: faceRect.height * 0.15
        ).intersection(extent)

        let hairRect = CGRect(
            x: faceRect.minX,
            y: faceRect.maxY - faceRect.height * 0.05,
            width: faceRect.width,
            height: faceRect.height * 0.2
        ).intersection(extent)

        guard let skinColor = averageColor(of: ciImage, in: skinRect),
              let hairColor = averageColor(of: ciImage, in: hairRect) else {
            return nil
        }

        return (skinColor.hexString, hairColor.hexString)
    }

    private static func averageColor(of image: CIImage, in rect: CGRect) -> UIColor? {
        guard rect.width > 0, rect.height > 0,
              let filter = CIFilter(name: "CIAreaAverage", parameters: [
                kCIInputImageKey: image,
                kCIInputExtentKey: CIVector(cgRect: rect)
              ]),
              let outputImage = filter.outputImage else {
            return nil
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext()
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return UIColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: 1
        )
    }
}
