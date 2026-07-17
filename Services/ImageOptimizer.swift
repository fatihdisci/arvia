import UIKit

// MARK: - Image Optimizer
// Belge arşivi ve fotoğraf saklama için görsel küçültme/yeniden kodlama.
// Amaç: büyük fotoğrafları (12MP+) makul boyuta indirip depolama, CloudKit
// senkron boyutu ve bellek kullanımını azaltmak. CPU-yoğun olduğu için
// çağıranlar bunu ana thread dışında (Task.detached) çalıştırmalıdır.
//
// nonisolated saf fonksiyonlar — global state yok, ağ yok.
enum ImageOptimizer {
    /// Ham görsel verisini en uzun kenarı `maxDimension` olacak şekilde küçültüp
    /// JPEG'e çevirir. Görsel zaten küçükse yalnızca yeniden kodlanır. Çözülemeyen
    /// veride nil döner (çağıran orijinaline geri düşebilir).
    static func optimizedJPEGData(
        from data: Data,
        maxDimension: CGFloat = 2048,
        compressionQuality: CGFloat = 0.8
    ) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let resized = downsample(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: compressionQuality)
    }

    /// Görseli en uzun kenarı `maxDimension`'a inecek şekilde orantılı küçültür.
    /// Zaten küçükse aynı görseli döndürür.
    static func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension, longestSide > 0 else { return image }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1 // Piksel boyutunu doğrudan kontrol et (ekran ölçeğiyle şişme yok).
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
