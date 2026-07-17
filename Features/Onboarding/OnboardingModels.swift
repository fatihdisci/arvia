import Foundation

// MARK: - Onboarding Models & Constants
// 1.1.0 onboarding'i amaç-odaklı, 6 ekranlı bir akıştır. Bu dosya akışın
// veri sözleşmesini (kullanıcı amacı, sürüm, AppStorage anahtarları) sabitler.

/// Kullanıcının Arvia'yı ne için kullanmak istediği. Onboarding 2. adımında
/// tek seçim olarak sorulur; ana ekran ilk kartı, paywall başlığı, analytics
/// segmentasyonu ve ilk önerilen işlem bu değere göre şekillenir.
enum OnboardingGoal: String, CaseIterable, Identifiable {
    case maintenance        // Bakım tarihlerini takip etmek
    case importantDates     // Muayene ve sigortayı unutmamak
    case expenses           // Araç masraflarını görmek
    case documents          // Belgeleri düzenlemek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .maintenance: return "Bakım tarihlerini takip etmek"
        case .importantDates: return "Muayene ve sigortayı unutmamak"
        case .expenses: return "Araç masraflarını görmek"
        case .documents: return "Belgelerimi düzenlemek"
        }
    }

    var icon: String {
        switch self {
        case .maintenance: return "wrench.and.screwdriver"
        case .importantDates: return "bell.badge"
        case .expenses: return "turkishlirasign.circle"
        case .documents: return "doc.text"
        }
    }

    /// Analytics'e giden değer — plaka/isim gibi PII içermez, sabit segment etiketidir.
    var analyticsValue: String { rawValue }
}

/// Onboarding akışının sürümü. Yeni bir köklü akış eklendikçe artırılır; eski
/// kullanıcıların yanlışlıkla yeniden onboarding'e düşmesini önlemek ve gelecekte
/// sürüme özel "yenilikler" deneyimleri koşullamak için kullanılır.
/// v1 = eski 5 slaytlık tanıtım. v2 = amaç-odaklı 6 adımlı akış.
enum OnboardingConstants {
    static let currentVersion = 2

    // AppStorage anahtarları — tek kaynak.
    static let completedKey = "onboarding_completed"
    static let versionKey = "onboarding_version"
    static let goalKey = "onboarding_primary_goal"
    static let stepKey = "onboarding_step"
}
