import Foundation
import UIKit
import UniformTypeIdentifiers

// MARK: - Document Storage Service
// Belgeleri app sandbox içinde UUID isimleriyle saklar.
// Orijinal dosya adı metadata olarak VehicleDocument modelinde tutulur.

final class DocumentStorageService {
    static let shared = DocumentStorageService()

    private let fileManager = FileManager.default

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VehicleDocuments", isDirectory: true)
    }

    private init() {
        try? fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Save
    /// Verilen URL'deki dosyayı UUID isimli olarak app storage'a kopyalar.
    /// - Parameters:
    ///   - sourceURL: Kaynak dosya URL'i (geçici import/photo URL'i)
    ///   - originalFileName: Orijinal dosya adı
    ///   - documentId: Belge UUID'si (dosya adı olarak kullanılır)
    /// - Returns: Hedef dosya adı (UUID) ve dosya boyutu (byte)
    func saveFile(from sourceURL: URL, originalFileName: String, documentId: UUID) throws -> (localFileName: String, fileSize: Int) {
        let ext = (originalFileName as NSString).pathExtension
        let localName = documentId.uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let destination = documentsDirectory.appendingPathComponent(localName)

        // Atomik yazma: yeni dosya tamamen yazılamazsa mevcut kopya korunur.
        let data = try Data(contentsOf: sourceURL)
        try data.write(to: destination, options: .atomic)

        let attributes = try fileManager.attributesOfItem(atPath: destination.path)
        let fileSize = (attributes[.size] as? Int) ?? 0

        return (localName, fileSize)
    }

    /// Başarısız bir metadata kaydından sonra önceki dosyayı atomik olarak geri yükler.
    func writeFileData(_ data: Data, localFileName: String) throws {
        try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        try data.write(
            to: documentsDirectory.appendingPathComponent(localFileName),
            options: .atomic
        )
    }

    // MARK: - Read
    /// Saklanan dosyanın URL'ini döndürür.
    func fileURL(for localFileName: String) -> URL {
        documentsDirectory.appendingPathComponent(localFileName)
    }

    /// Dosyanın var olup olmadığını kontrol eder.
    func fileExists(_ localFileName: String) -> Bool {
        let url = documentsDirectory.appendingPathComponent(localFileName)
        return fileManager.fileExists(atPath: url.path)
    }

    /// Diskteki dosyanın ikili içeriğini okur (CloudKit'e backfill için).
    func readFileData(_ localFileName: String) -> Data? {
        guard !localFileName.isEmpty else { return nil }
        let url = documentsDirectory.appendingPathComponent(localFileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Önizleme için yerel dosya URL'i döndürür.
    /// Dosya diskte yoksa ancak CloudKit'ten gelen `data` mevcutsa, dosyayı diske
    /// yazıp (çalışma kopyası olarak) URL döndürür. İkisi de yoksa nil döner.
    func materializeFileIfNeeded(localFileName: String, data: Data?) -> URL? {
        guard !localFileName.isEmpty else { return nil }
        let url = documentsDirectory.appendingPathComponent(localFileName)
        if fileManager.fileExists(atPath: url.path) { return url }
        guard let data else { return nil }
        do {
            try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Delete
    /// Dosyayı diskten siler.
    func deleteFile(_ localFileName: String) throws {
        let url = documentsDirectory.appendingPathComponent(localFileName)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    /// Tüm belge dosyalarını ve dizini temizler.
    func deleteAllFiles() {
        let url = documentsDirectory
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
        // Dizini yeniden oluştur ki sonraki kayıtlar patlamasın
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    // MARK: - Utility
    /// Dosya boyutunu döndürür (byte).
    func fileSize(for localFileName: String) -> Int? {
        let url = documentsDirectory.appendingPathComponent(localFileName)
        guard fileManager.fileExists(atPath: url.path),
              let attrs = try? fileManager.attributesOfItem(atPath: url.path)
        else { return nil }
        return (attrs[.size] as? Int)
    }

    /// Toplam kullanılan depolama alanı (byte).
    var totalStorageUsed: Int {
        guard let files = try? fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: [.fileSizeKey])
        else { return 0 }
        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + size
        }
    }

    /// Depolama alanı formatlı string.
    var totalStorageDisplay: String {
        let bytes = totalStorageUsed
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return "\(bytes / 1024) KB" }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576.0)
    }

    /// Güvenli dosya adı oluşturur (Türkçe karakterleri temizler).
    static func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }
}
