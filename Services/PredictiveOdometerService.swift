import Foundation

// MARK: - Predictive Odometer Service (Layer B)
// Aracın güncel kilometresini cihaz üstünde tahmin eder. Rule-based, ağ yok.
// Birincil sinyal: son 90 günde masraf/bakım kayıtlarındaki km değerleri → günlük km
// ortalaması → son gerçek okumadan ekstrapolasyon.
// Yedek: veri yoksa profil dailyKmBand orta noktası.
final class PredictiveOdometerService {
    static let shared = PredictiveOdometerService()

    init() {}

    // MARK: - Types
    struct Reading: Equatable {
        let date: Date
        let odometer: Int
    }

    enum Confidence: String, Equatable {
        case high   // veri odaklı
        case low    // yalnızca profil
    }

    struct Estimate: Equatable {
        let estimatedOdometer: Int
        let confidence: Confidence
        let daysSinceLastReading: Int
        let dailyKmAverage: Double
        let isDataDriven: Bool
    }

    // MARK: - Estimate
    /// - Parameters:
    ///   - lastKnownOdometer: Aracın bilinen son km değeri (Vehicle.currentOdometer).
    ///   - lastKnownDate: Son bilinen km'nin okunduğu tarih (manuel güncelleme veya kayıt).
    ///   - readings: Tarihli km kanıtları (masraf/bakım/ekspertiz).
    ///   - profileBand: Kullanım profili günlük km bandı (yedek sinyal).
    ///   - now: Referans an (test için enjekte edilebilir).
    /// - Returns: Tahmin; hiçbir taban tarih/km yoksa nil.
    func estimate(
        lastKnownOdometer: Int,
        lastKnownDate: Date?,
        readings: [Reading],
        profileBand: DailyKmBand?,
        now: Date = Date(),
        windowDays: Int = 90
    ) -> Estimate? {
        let calendar = Calendar(identifier: .gregorian)

        // Pencere içi, km'si artan, tarihli okumalar.
        let windowStart = calendar.date(byAdding: .day, value: -windowDays, to: now) ?? now
        let windowReadings = readings
            .filter { $0.date >= windowStart && $0.date <= now }
            .sorted { $0.date < $1.date }

        // Veri odaklı yol: en az iki farklı tarihte artan km.
        if let first = windowReadings.first,
           let last = windowReadings.last,
           last.odometer > first.odometer {
            let spanDays = max(1, calendar.dateComponents([.day], from: first.date, to: last.date).day ?? 0)
            if spanDays >= 1 {
                let dailyKm = Double(last.odometer - first.odometer) / Double(spanDays)
                let daysSince = max(0, calendar.dateComponents([.day], from: last.date, to: now).day ?? 0)
                let projected = last.odometer + Int((dailyKm * Double(daysSince)).rounded())
                return Estimate(
                    estimatedOdometer: max(projected, last.odometer),
                    confidence: .high,
                    daysSinceLastReading: daysSince,
                    dailyKmAverage: dailyKm,
                    isDataDriven: true
                )
            }
        }

        // Yedek yol: profil bandı orta noktası.
        guard let band = profileBand else { return nil }

        // Taban okuma: en güncel gerçek okuma tarihi.
        let baseDate = ([lastKnownDate].compactMap { $0 } + windowReadings.map { $0.date }).max()
        guard let base = baseDate else { return nil }

        let dailyKm = Double(band.midpointKm)
        let daysSince = max(0, calendar.dateComponents([.day], from: base, to: now).day ?? 0)
        let projected = lastKnownOdometer + Int((dailyKm * Double(daysSince)).rounded())
        return Estimate(
            estimatedOdometer: max(projected, lastKnownOdometer),
            confidence: .low,
            daysSinceLastReading: daysSince,
            dailyKmAverage: dailyKm,
            isDataDriven: false
        )
    }
}
