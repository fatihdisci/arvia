import Foundation
import Vision
import UIKit

// MARK: - OCR Service
// Vision VNRecognizeTextRequest ile cihaz üstü metin tanıma. Ağ yok.
// Türkçe + İngilizce, doğruluk (accurate) modu. Sayfa başına async tanıma yapar
// ve sonuçları sayfa işaretçileriyle birleştirir.
final class OCRService {
    static let shared = OCRService()

    init() {}

    enum OCRError: Error {
        case invalidImage
        case recognitionFailed
    }

    // MARK: - Tek sayfa
    /// Tek bir görüntüyü tanır, satırları newline ile birleştirilmiş metin döndürür.
    func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw OCRError.invalidImage }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if error != nil {
                    continuation.resume(throwing: OCRError.recognitionFailed)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["tr-TR", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed)
            }
        }
    }

    // MARK: - Çok sayfa
    /// Birden çok sayfayı sırayla tanır ve sayfa işaretçileriyle birleştirir.
    /// Bir sayfa tanınamazsa boş metinle geçilir (tüm işlem durmaz).
    func recognizeText(in images: [UIImage]) async -> String {
        var parts: [String] = []
        for (index, image) in images.enumerated() {
            let pageText = (try? await recognizeText(in: image)) ?? ""
            parts.append("--- Sayfa \(index + 1) ---")
            parts.append(pageText)
        }
        return parts.joined(separator: "\n")
    }
}
