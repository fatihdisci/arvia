import Foundation

// MARK: - Maintenance Advisor Service (Layer B)
// Profil + araç (yakıt/yaş) + tahmini günlük km birleştirerek kişiselleştirilmiş,
// kural tabanlı bakım önerileri üretir. Ağ yok, LLM yok. Kural tablosu genişletmeye
// açık şekilde yapılandırıldı.
final class MaintenanceAdvisorService {
    static let shared = MaintenanceAdvisorService()

    init() {}

    // MARK: - Input
    struct Input: Equatable {
        var fuelType: FuelType
        var vehicleYear: Int?
        var currentOdometer: Int
        var dailyKm: Double
        var routeType: RouteType?
        var dailyKmBand: DailyKmBand?
        var now: Date

        var ageYears: Int? {
            guard let vehicleYear else { return nil }
            let currentYear = Calendar(identifier: .gregorian).component(.year, from: now)
            return max(0, currentYear - vehicleYear)
        }
    }

    // MARK: - Suggestion (rule output)
    struct Suggestion: Equatable {
        let ruleId: String
        let title: String
        let message: String
        let severity: VehicleInsightPriority
        /// Opsiyonel önerilen hatırlatıcı payload'u.
        let suggestedReminderType: ReminderType?
    }

    // MARK: - Rule table
    // Her kural (id, koşul, çıktı). Sıra önem taşır: eşit ciddiyet durumunda üstteki kazanır.
    private struct Rule {
        let id: String
        let severity: VehicleInsightPriority
        let matches: (Input) -> Bool
        let build: (Input) -> Suggestion
    }

    private var rules: [Rule] {
        [
            // 1) Triger seti — 100.000 km yaklaşıyor + triger yaşına uygun (>=6 yıl).
            Rule(id: "timingBelt100k", severity: .important, matches: { input in
                (90_000...100_000).contains(input.currentOdometer) && (input.ageYears ?? 0) >= 6
            }, build: { input in
                let remaining = max(0, 100_000 - input.currentOdometer)
                let eta = Self.monthsETA(remainingKm: remaining, dailyKm: input.dailyKm)
                let etaText = eta.map { "senin kullanımınla ~\($0) ay sonra" } ?? "yakında"
                return Suggestion(
                    ruleId: "timingBelt100k",
                    title: "Triger seti kontrolü",
                    message: "100.000 km eşiğine yaklaşıyorsun (\(etaText)). Triger seti bu aralıkta kontrol edilmeli; kopması motora ağır zarar verebilir.",
                    severity: .important,
                    suggestedReminderType: .timingBelt
                )
            }),

            // 2) Çok yüksek günlük km — daha sık genel bakım.
            Rule(id: "veryHighDailyKm", severity: .warning, matches: { input in
                input.dailyKm >= 100 || input.dailyKmBand == .over100
            }, build: { _ in
                Suggestion(
                    ruleId: "veryHighDailyKm",
                    title: "Yoğun kullanım — sık bakım",
                    message: "Günlük kilometren yüksek. Periyodik bakım aralığını takvimden çok kilometreye göre planlamak motor ömrü için faydalı olur.",
                    severity: .warning,
                    suggestedReminderType: .periodicService
                )
            }),

            // 3) Yüksek günlük km + şehir içi — daha kısa yağ değişim aralığı.
            Rule(id: "highCityOilInterval", severity: .warning, matches: { input in
                (input.dailyKm >= 50 || input.dailyKmBand == .from50to100 || input.dailyKmBand == .over100)
                    && input.routeType == .city
            }, build: { _ in
                Suggestion(
                    ruleId: "highCityOilInterval",
                    title: "Yağ değişim aralığını kısalt",
                    message: "Şehir içi yoğun kullanımda motor daha çok yük altında çalışır. Yağ değişimini önerilen aralığın biraz altında planlamak faydalı olabilir.",
                    severity: .warning,
                    suggestedReminderType: .oilChange
                )
            }),

            // 4) Otoyol ağırlıklı — lastik aşınma kontrolü.
            Rule(id: "highwayTireWear", severity: .info, matches: { input in
                input.routeType == .highway
            }, build: { _ in
                Suggestion(
                    ruleId: "highwayTireWear",
                    title: "Lastik aşınma kontrolü",
                    message: "Otoyol ağırlıklı kullanımda lastik sıcaklığı ve aşınması artar. Diş derinliği ve basınç kontrolünü kayıt altında tutmak faydalı olur.",
                    severity: .info,
                    suggestedReminderType: .tire
                )
            }),

            // 5) LPG — subap (valve clearance) ayarı kadansı.
            Rule(id: "lpgValveClearance", severity: .warning, matches: { input in
                input.fuelType == .lpg
            }, build: { _ in
                Suggestion(
                    ruleId: "lpgValveClearance",
                    title: "Subap ayarı hatırlatması",
                    message: "LPG'li motorlarda subap boşluğu (valf ayarı) daha sık kontrol gerektirir. Uzman serviste periyodik ayar, motor sağlığı için önemlidir.",
                    severity: .warning,
                    suggestedReminderType: .periodicService
                )
            }),

            // 6) Dizel + yüksek şehir içi — DPF rejenerasyon notu.
            Rule(id: "dieselCityDPF", severity: .info, matches: { input in
                input.fuelType == .diesel && (input.routeType == .city) && input.dailyKm >= 30
            }, build: { _ in
                Suggestion(
                    ruleId: "dieselCityDPF",
                    title: "DPF için ara sıra uzun yol",
                    message: "Şehir içi kısa mesafelerde dizel partikül filtresi (DPF) tam rejenerasyon yapamayabilir. Ara sıra uzun yol, filtrenin temizlenmesine yardımcı olur.",
                    severity: .info,
                    suggestedReminderType: nil
                )
            }),

            // 7) Elektrikli — mevsimsel batarya sağlığı notu.
            Rule(id: "electricBatterySeasonal", severity: .info, matches: { input in
                input.fuelType == .electric
            }, build: { input in
                let month = Calendar(identifier: .gregorian).component(.month, from: input.now)
                let winter = [12, 1, 2].contains(month)
                return Suggestion(
                    ruleId: "electricBatterySeasonal",
                    title: "Batarya sağlığı",
                    message: winter
                        ? "Soğuk havada menzil düşebilir. Kışın aracı mümkünse şarjlı ve ılık ortamda tutmak batarya sağlığına iyi gelir."
                        : "Elektrikli araçta batarya sağlığını korumak için çok sık %100 şarj ve derin deşarjdan kaçınmak faydalıdır.",
                    severity: .info,
                    suggestedReminderType: nil
                )
            }),

            // 8) Hibrit — sistem/batarya periyodik kontrol.
            Rule(id: "hybridSystemCheck", severity: .info, matches: { input in
                input.fuelType == .hybrid
            }, build: { _ in
                Suggestion(
                    ruleId: "hybridSystemCheck",
                    title: "Hibrit sistem kontrolü",
                    message: "Hibrit araçlarda yüksek voltaj bataryası ve invertör soğutması periyodik kontrol ister. Bakım kayıtlarını ayrı tutmak takibi kolaylaştırır.",
                    severity: .info,
                    suggestedReminderType: .periodicService
                )
            }),

            // 9) Düşük günlük km + yaşlı araç — zamana bağlı yağ yaşlanması.
            Rule(id: "lowKmOilAging", severity: .info, matches: { input in
                (input.dailyKm <= 20 || input.dailyKmBand == .under20) && (input.ageYears ?? 0) >= 5
            }, build: { _ in
                Suggestion(
                    ruleId: "lowKmOilAging",
                    title: "Yağ zamanla da yaşlanır",
                    message: "Az kullanılsa bile motor yağı zamanla özelliğini yitirir. Kilometre dolmasa da yılda bir yağ değişimi önerilir.",
                    severity: .info,
                    suggestedReminderType: .oilChange
                )
            }),

            // 10) Benzin + yüksek km — buji kontrolü.
            Rule(id: "gasolineSparkPlug", severity: .info, matches: { input in
                input.fuelType == .gasoline && input.currentOdometer >= 60_000
            }, build: { _ in
                Suggestion(
                    ruleId: "gasolineSparkPlug",
                    title: "Buji kontrolü",
                    message: "Bu kilometre aralığında bujilerin durumu ateşleme verimini etkiler. Kontrol/değişim, yakıt tüketimi ve performans için faydalı olabilir.",
                    severity: .info,
                    suggestedReminderType: nil
                )
            }),
        ]
    }

    // MARK: - API
    /// Eşleşen tüm önerileri ciddiyet (important > warning > info) ve kural sırasına göre döndürür.
    func suggestions(for input: Input) -> [Suggestion] {
        rules
            .filter { $0.matches(input) }
            .map { $0.build(input) }
            .sorted { Self.severityRank($0.severity) > Self.severityRank($1.severity) }
    }

    /// Günün tek önerisi — en yüksek ciddiyetli (eşitlikte kural sırası).
    func topSuggestion(for input: Input) -> Suggestion? {
        suggestions(for: input).first
    }

    // MARK: - Helpers
    static func monthsETA(remainingKm: Int, dailyKm: Double) -> Int? {
        guard dailyKm > 0, remainingKm > 0 else { return nil }
        let days = Double(remainingKm) / dailyKm
        return max(1, Int((days / 30.0).rounded()))
    }

    static func severityRank(_ p: VehicleInsightPriority) -> Int {
        switch p {
        case .important: return 3
        case .warning: return 2
        case .info: return 1
        }
    }
}
