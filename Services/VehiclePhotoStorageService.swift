import Foundation
import UIKit

// MARK: - Vehicle Photo Storage Service
// Araç fotoğrafları için izole dosya storage'ı.
// DocumentStorageService'ten bağımsızdır; VehicleDocuments ile karışmaz.

final class VehiclePhotoStorageService {
    static let shared = VehiclePhotoStorageService()

    private let directoryName = "VehiclePhotos"

    private var directoryURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(directoryName)
    }

    init() {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    // MARK: - Save

    /// Fotoğrafı JPEG olarak kaydeder, dosya adını döndürür.
    /// - Parameter image: Kaydedilecek UIImage
    /// - Returns: Kaydedilen dosyanın adı (UUID.jpg)
    /// - Throws: VehiclePhotoError.tooLarge (20 MB üstü)
    func savePhoto(_ image: UIImage) throws -> String {
        try savePhotoReturningData(image).fileName
    }

    /// Diske kaydeder ve CloudKit senkronu için JPEG Data'yı da döndürür.
    func savePhotoReturningData(_ image: UIImage) throws -> (fileName: String, data: Data) {
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = directoryURL.appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.85),
              data.count < 20_971_520 else {
            throw VehiclePhotoError.tooLarge
        }

        try data.write(to: fileURL, options: .atomic)
        return (fileName, data)
    }

    /// Diskteki fotoğrafın ikili içeriğini okur (CloudKit backfill için).
    func readPhotoData(fileName: String) -> Data? {
        guard !fileName.isEmpty else { return nil }
        let url = directoryURL.appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }

    // MARK: - Load

    /// Dosya adına göre fotoğrafı yükler.
    func loadPhoto(fileName: String) -> UIImage? {
        loadPhoto(fileName: fileName, syncedData: nil)
    }

    /// Diskte dosya yoksa ama CloudKit'ten `syncedData` geldiyse dosyayı diske yazıp
    /// (çalışma kopyası) UIImage döndürür. Aksi halde diskteki dosyayı okur.
    func loadPhoto(fileName: String, syncedData: Data?) -> UIImage? {
        let url = directoryURL.appendingPathComponent(fileName)
        if let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        guard let syncedData else { return nil }
        try? syncedData.write(to: url, options: .atomic)
        return UIImage(data: syncedData)
    }

    // MARK: - Delete

    /// Tek bir fotoğraf dosyasını siler.
    func deletePhoto(fileName: String) {
        let url = directoryURL.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    /// Tüm araç fotoğraflarını siler (hesap silme senaryosu).
    func deleteAllPhotos() {
        try? FileManager.default.removeItem(at: directoryURL)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    // MARK: - Errors

    enum VehiclePhotoError: LocalizedError {
        case tooLarge

        var errorDescription: String? {
            "Fotoğraf 20 MB'dan büyük olamaz."
        }
    }
}
