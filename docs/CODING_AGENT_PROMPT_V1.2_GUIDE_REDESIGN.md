# Coding Agent Prompt — Faz 1.1: Arvia Rehber İçerik Stratejisi

> **Bu prompt, MVP sonrası ilk güncelleme (v1.1) için code agent'ın çalıştıracağı içerik stratejisi uygulamasını tarif eder.**
> Ön koşul: MVP `main` branch'i yeşil, 151 test geçiyor, TestFlight internal testing başlatılmış.
> Karar manifestosu: `ROADMAP.md` → Faz 1.1 + Karar 4.2.
> Gemini araştırma raporu: `docs/RESEARCH_ARVIA_GUIDE_SCENARIOS.md` (670 satır, 39 kaynak).
> Önceki fix promptları: `docs/CODING_AGENT_PROMPT_OPEN_MODE_FIXES.md`, `docs/CODING_AGENT_PROMPT_MVP_FIXES.md`.

---

## İlgili dosyalar — MUTLAKA OKU

**Karar ve bağlam:**
- `/Users/fatihdisci/apps/arvia/ROADMAP.md` → Faz 1.1 + Karar 4.2 bölümü (öncelik sırası, 5 içerik tipi, eşleme tablosu, Swift mimari)
- `/Users/fatihdisci/apps/arvia/01_DESIGN.md` → tasarım anayasası (token-only, AI-slop yasak, bilgi > eylem)
- `/Users/fatihdisci/apps/arvia/docs/RESEARCH_ARVIA_GUIDE_SCENARIOS.md` → Gemini raporu (ton kuralları, best practice, mimari öneriler, test senaryoları — BÖLÜM 5'i özellikle oku)

**Mevcut kod — referans:**
- `/Users/fatihdisci/apps/arvia/Models/VehicleInsight.swift` → mevcut 13 insight tipi + 10 action enum
- `/Users/fatihdisci/apps/arvia/Services/VehicleInsightService.swift` → kural motoru (5 fonksiyon: contextualInsights, overdueReminderInsights, upcomingReminderInsight, odometerUpdateInsight, calendarPeriodInsight, seasonalGuidanceInsight, profileGuidanceInsights, odometerMilestoneInsight, monthlyExpensePromptInsight, noServiceRecordInsight, oldServiceRecordInsight, noDocumentInsight, quietGoodStateInsight)
- `/Users/fatihdisci/apps/arvia/Services/InsightSnoozeStore.swift` → mevcut snooze store (şu an sadece `.calendarPeriod` için var, genişletilecek)
- `/Users/fatihdisci/apps/arvia/DesignSystem/Components/OwnershipInsightCard.swift` → mevcut rehber kartı componenti (refactor edilecek)
- `/Users/fatihdisci/apps/arvia/Services/DemoDataSeeder.swift` → mevcut seed (5 yeni senaryo eklenecek)
- `/Users/fatihdisci/apps/arvia/Features/VehicleDetail/VehicleDetailView.swift` → rehber kullanım yeri (satır ~1840-1910 arası)
- `/Users/fatihdisci/apps/arvia/Features/Garage/GarageView.swift` → rehber kullanım yeri (Garaj daily summary)

**Dokunma:**
- `/Users/fatihdisci/apps/arvia/Configuration/`, `Resources/`, `build/`, `docs/` (bu prompt dışı)
- `.xcconfig`, `.xcprivacy`, `.entitlements`, `Info.plist`, `.pbxproj`
- `ROADMAP.md`, `01_DESIGN.md` (kanun dokümanları)
- Mevcut testler silinmez / geçersiz kılınmaz

---

## Context

Arvia TestFlight'ta 5-10 kişilik internal testing grubunda. Kullanıcı geri bildirimi: rehber kartları "robotik" ve "eyleme zorlayan" hissi veriyor. 13 kartın hepsi CTA-zorunlu. Gemini Deep Research raporuna göre 5 içerik tipi kategorisi (CTA/Bilgi/Uyarı/Hatırlatma/Soru) benimsendi. Bu Faz 1.1'de **kod tarafına geçirilecek**.

**Mimari özet (Gemini raporu Bölüm 5):**
1. `VehicleInsight.action` → opsiyonel (`VehicleInsightAction?`). `nil` = CTA yok.
2. Yeni enum `VehicleInsightContentKind` (5 case).
3. Yeni `VehicleInsightAction` case'leri (dismiss/acknowledge/noAction).
4. `InsightSnoozeStore` → UserDefaults tabanlı, genel API.
5. Yeni component `VehicleInsightCard` (dismiss + çift buton).
6. SwiftData migration: zorunlu `action` → opsiyonel `action` + yeni `contentKind`.
7. 13 mevcut kartın metni ton kurallarına göre yeniden yazılacak.
8. DemoDataSeeder 5 senaryo.

---

## Hard constraints (BUNLARI İHLAL ETME)

- ❌ Mevcut MVP davranışını değiştirme — sadece **yapı** ve **metin**.
- ❌ Mevcut 13 insight tipinin semantiğini değiştirme — sadece CTA/dismiss davranışını değiştir.
- ❌ `Color.appBorder`, `Color.appSurface` token'larını değiştirme (Karar 4.1 bunları kilitledi).
- ❌ `01_DESIGN.md`, `ROADMAP.md` dokümanlarını değiştirme.
- ❌ `Configuration/`, `Resources/`, `build/`, `.xcconfig`, `.xcprivacy`, `.entitlements`, `Info.plist`, `.pbxproj` değiştirme.
- ❌ SPM dependency ekleme, yeni framework import etme.
- ❌ AI-slop — mavi-mor gradient, glassmorphism, "dostum" samimiyeti, "hemen yapın" emri dili.
- ❌ Token dışı ham hex.
- ❌ Mevcut testleri silme / geçersiz kılma.

## Soft constraints

- Her adım sonrası `xcodebuild test -scheme Ruhsatim -destination 'platform=iOS Simulator,name=iPhone 17'` çalıştır.
- 151 test geçmeli (veya yenileri eklenirse daha fazla).
- Migration **veri kaybı olmamalı** — mevcut insight kayıtları korunmalı.
- PR tek commit olabilir, branch'e gerek yok, doğrudan `main`'e.
- Bu prompt tek PR'da tamamlanacak.

---

# Fix 1.1.1 — Model: opsiyonel action + ContentKind enum

**Karar:** ROADMAP Karar 4.2 + Gemini raporu Bölüm 5.1.

**Dosya:** `Models/VehicleInsight.swift`

**Yapılacak:**

### 1. VehicleInsight struct

`action` alanını opsiyonel yap:
```swift
struct VehicleInsight {
    // ... mevcut alanlar ...
    let contentKind: VehicleInsightContentKind  // YENİ
    let action: VehicleInsightAction?            // OPSİYONEL OLDU
    let snoozeDays: Int?                        // YENİ — nil ise dismiss edilemez
    // ...
}
```

### 2. VehicleInsightContentKind enum (yeni)

`VehicleInsight.swift` dosyasına ekle:
```swift
enum VehicleInsightContentKind: String, Codable, CaseIterable {
    case callToAction   // A. Eylem — zorunlu CTA
    case info           // B. Bilgi — sadece dismiss
    case warning        // C. Uyarı — geçmiş + dismiss
    case reminder       // D. Hatırlatma — sadece dismiss
    case softQuestion   // E. Soru — ekle + "Şimdi Değil"
}
```

### 3. VehicleInsightAction'a yeni case'ler

Mevcut 10 case korunur + 4 yeni:
```swift
enum VehicleInsightAction: String, CaseIterable {
    // Mevcut (korunur)
    case addServiceRecord, addDocument, openSaleFile, updateOdometer,
         openTodos, addInspectionReport, addReminder, addMTVReminder,
         addExpense, addFuelExpense
    // Yeni
    case dismissAndSnooze   // Kullanıcı dismiss + snooze
    case markAsRead         // Sadece okundu işaretle
    case acknowledge        // "Anlaşıldı"
    case noAction           // Pasif, göster ama etkileşim yok
}
```

### 4. init güncellemesi

Mevcut `init(...)` çağrılarında `action` parametresi opsiyonel olur, `contentKind` zorunlu eklenir. Tüm mevcut çağrı yerleri güncellenmeli.

**Acceptance:**
- Derleme hatası yok
- Mevcut 13 tip için uygun `contentKind` atanmış (aşağıdaki eşleme tablosuna göre)
- `VehicleInsight` SwiftData uyumlu (Codable)

---

# Fix 1.1.2 — InsightSnoozeStore: UserDefaults tabanlı genel API

**Karar:** ROADMAP Karar 4.2 + Gemini raporu Bölüm 5.3.

**Dosya:** `Services/InsightSnoozeStore.swift`

**Yapılacak:**

Mevcut yapıyı genel bir UserDefaults API'sine dönüştür. Anahtar formatı: `com.arvia.snooze.{vehicleId}.{insightType}`.

```swift
import Foundation

final class InsightSnoozeStore {
    static let shared = InsightSnoozeStore()
    private let userDefaults: UserDefaults
    private let keyPrefix = "com.arvia.snooze."

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func snooze(
        insightType: VehicleInsightType,
        forVehicle vehicleId: UUID,
        days: Int
    ) {
        let expireDate = Date().addingTimeInterval(TimeInterval(days * 24 * 60 * 60))
        let key = makeKey(insightType: insightType, vehicleId: vehicleId)
        userDefaults.set(expireDate.timeIntervalSince1970, forKey: key)
    }

    func isSnoozed(
        insightType: VehicleInsightType,
        forVehicle vehicleId: UUID
    ) -> Bool {
        let key = makeKey(insightType: insightType, vehicleId: vehicleId)
        guard let savedTime = userDefaults.object(forKey: key) as? Double else {
            return false
        }
        let expireDate = Date(timeIntervalSince1970: savedTime)
        if Date() > expireDate {
            userDefaults.removeObject(forKey: key)
            return false
        }
        return true
    }

    func clearSnooze(
        insightType: VehicleInsightType,
        forVehicle vehicleId: UUID
    ) {
        let key = makeKey(insightType: insightType, vehicleId: vehicleId)
        userDefaults.removeObject(forKey: key)
    }

    func removeExpired() {
        // Mevcut API korunur
    }

    private func makeKey(insightType: VehicleInsightType, vehicleId: UUID) -> String {
        "\(keyPrefix)\(vehicleId.uuidString).\(insightType.rawValue)"
    }
}
```

**Mevcut API:** `clearReminderSnoozes(for:vehicle, types:)` korunur (geriye uyumluluk).

**Acceptance:**
- `isSnoozed(insightType:forVehicle:)` herhangi bir insight tipi için çalışır
- `snooze(...)` süre dolunca `isSnoozed` true döner, sonra false
- `removeExpired()` artık eski sistemle uyumlu

---

# Fix 1.1.3 — VehicleInsightService: her insight için contentKind + snoozeDays ata

**Karar:** ROADMAP Karar 4.2 eşleme tablosu.

**Dosya:** `Services/VehicleInsightService.swift`

**Yapılacak:**

Aşağıdaki eşleme tablosuna göre **her insight üretim fonksiyonu** güncellenecek. Her insight constructor'ına `contentKind` ve `snoozeDays` eklenecek.

| Mevcut tip | contentKind | snoozeDays | action davranışı |
|---|---|---|---|
| `overdueReminder` | `.callToAction` | `nil` | openTodos (zorunlu) |
| `upcomingReminder` | `.warning` | `14` | addReminder veya dismissAndSnooze |
| `calendarPeriod` | `.reminder` | dönem sonu (Ocak: 31, Temmuz: 31, sonraki ay 1) | addMTVReminder veya dismissAndSnooze |
| `odometerUpdate` | `.softQuestion` | `30` | updateOdometer veya noAction |
| `seasonalGuidance` | `.info` | `90` | acknowledge |
| `fuelTypeGuidance` | `.info` | `60` | acknowledge |
| `transmissionGuidance` | `.warning` | `30` | addServiceRecord veya dismissAndSnooze |
| `odometerMilestone` | `.info` | `nil` (kalıcı) | acknowledge |
| `monthlyExpensePrompt` | `.softQuestion` | `30` | addExpense veya noAction |
| `maintenance` (noServiceRecord) | `.warning` | `14` | addServiceRecord veya dismissAndSnooze |
| `maintenance` (oldServiceRecord) | `.warning` | `14` | addServiceRecord veya dismissAndSnooze |
| `missingDocument` | `.callToAction` | `nil` | addDocument (zorunlu) |
| `quietGoodState` | `.reminder` | `7` | acknowledge |
| `saleFileReadiness` | `.info` | `30` | openSaleFile veya acknowledge |

**`contextualInsights(...)` filtresine** ekleme: snooze edilmiş insight'ları filtrele:
```swift
let activeInsights = generated.filter { insight in
    !snoozeStore.isSnoozed(
        insightType: insight.type,
        forVehicle: vehicle.id
    )
}
```

**Acceptance:**
- 13 üretim fonksiyonunun hepsi `contentKind` ve `snoozeDays` set ediyor
- Snooze edilmiş insight'lar `insights(...)` çıktısında yok
- Garaj daily summary ve Araç Detay rehber aynı filtreyi kullanır

---

# Fix 1.1.4 — Component: VehicleInsightCard (dismiss + çift buton)

**Karar:** Gemini raporu Bölüm 5.4.

**Dosya:** `DesignSystem/Components/VehicleInsightCard.swift` (yeni)

**Yapılacak:**

Yeni component mevcut `OwnershipInsightCard`'ın yerine geçer (veya yanına eklenir, hangisi daha temiz ise).

```swift
struct VehicleInsightCard: View {
    let insight: VehicleInsight
    let vehicleId: UUID
    var onAction: (VehicleInsightAction) -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Üst satır: ikon + başlık + (varsa) dismiss butonu
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(iconColor.opacity(0.12)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Text(insight.body)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppSpacing.xs)

                if insight.contentKind != .callToAction {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textTertiary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Anlaşıldı, kapat")
                }
            }

            // Alt satır: CTA buton(lar)ı
            if let action = insight.action {
                actionButtons(action: action)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border.opacity(0.85), lineWidth: 0.5)
        )
        .cardShadow()
    }

    @ViewBuilder
    private func actionButtons(action: VehicleInsightAction) -> some View {
        switch insight.contentKind {
        case .softQuestion:
            // Çift buton: "Ekle" + "Şimdi Değil"
            HStack(spacing: AppSpacing.sm) {
                Button { onAction(action) } label: {
                    Text(actionTitle(action))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)

                Button { onDismiss() } label: {
                    Text("Şimdi Değil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondary)
            }
        case .callToAction:
            // Tek zorunlu buton
            Button { onAction(action) } label: {
                Text(actionTitle(action))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
        case .info, .reminder, .warning:
            // info/reminder için sadece dismiss butonu zaten üstte
            // warning için inline "Bakım Geçmişi" + dismiss
            if insight.contentKind == .warning {
                Button { onAction(action) } label: {
                    HStack {
                        Text(actionTitle(action))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.text)
            }
            // info/reminder: no inline button (dismiss üstte)
            EmptyView()
        }
    }

    private var iconName: String {
        switch insight.contentKind {
        case .callToAction: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.octagon.fill"
        case .reminder: return "bell.fill"
        case .softQuestion: return "questionmark.bubble.fill"
        }
    }

    private var iconColor: Color {
        switch insight.contentKind {
        case .callToAction: return AppColors.critical
        case .info: return AppColors.accentPrimary
        case .warning: return AppColors.warning
        case .reminder: return AppColors.accentSecondary
        case .softQuestion: return AppColors.accentPrimary
        }
    }

    private func actionTitle(_ action: VehicleInsightAction) -> String {
        switch action {
        case .addServiceRecord: return "Bakım Kaydı Ekle"
        case .addDocument: return "Belge Ekle"
        case .openSaleFile: return "Satış Dosyasına Git"
        case .updateOdometer: return "Kilometre Güncelle"
        case .openTodos: return "Yapılacaklara Git"
        case .addInspectionReport: return "Ekspertiz Ekle"
        case .addReminder: return "Hatırlatıcı Ekle"
        case .addMTVReminder: return "MTV Hatırlatıcısı Ekle"
        case .addExpense: return "Masraf Ekle"
        case .addFuelExpense: return "Yakıt Ekle"
        default: return "Detayları Gör"
        }
    }
}
```

**`onDismiss` callback'i:**
```swift
if let days = insight.snoozeDays {
    InsightSnoozeStore.shared.snooze(
        insightType: insight.type,
        forVehicle: vehicleId,
        days: days
    )
}
// View'dan kaldır (parent'ta filter)
```

**Acceptance:**
- 5 content kind için doğru görsel (ikon + renk + buton yapısı)
- `.callToAction` dışındaki tüm kartlarda dismiss butonu var
- `.softQuestion` çift buton (Ekle + Şimdi Değil)
- Dismiss → `InsightSnoozeStore.snooze(...)` çağrılır

---

# Fix 1.1.5 — 13 kart metnini ton kurallarına göre yeniden yaz

**Karar:** Gemini raporu Bölüm 3 (ton ve üslup kuralları).

**Dosya:** `Services/VehicleInsightService.swift` (her insight constructor'ındaki `title` ve `body`)

**5 dil kuralı:**

1. Edilgen ve yardımcı fiillerle yumuşatma — "yap/et/gir/yükle" yok
2. Gerekçe gösterme — veri girişi isteniyorsa faydası açıklanmalı
3. Teknik terim parantez içi açıklaması — DPF, SoH, MTV
4. Karakter limitleri — başlık ≤ 30 karakter, gövde ≤ 120 karakter
5. "Sen" dili ama mesafeli — "dostum" gibi AI-slop yok

**Yeni metinler:**

```swift
// overdueReminder (.callToAction)
title: "Muayene süresi doldu"
body: "TÜVTÜRK muayene geçerlilik süren tükenmiş görünüyor. Trafik cezası riski için kaydı güncelleyebilirsin."

// upcomingReminder (.warning)
title: "Yaklaşan muayene"
body: "Muayene tarihin yaklaşıyor. Randevu almak için hatırlatıcı ekleyebilirsin."

// calendarPeriod (.reminder, MTV)
title: month == 1 ? "MTV 1. taksit dönemi" : "MTV 2. taksit dönemi"
body: month == 1
    ? "Ocak ayı MTV ödemeleri başladı. Ödedikten sonra masraf olarak kaydedebilirsin."
    : "Temmuz ayı MTV ödemeleri başladı. Ödedikten sonra masraf olarak kaydedebilirsin."

// odometerUpdate (.softQuestion)
title: "Kilometren güncel mi?"
body: "Aracınla son seyahatinden bu yana zaman geçti. Güncel km girmek, bakım zamanlarını doğru tahmin etmemize yardımcı olur."

// seasonalGuidance (.info)
title: season.title  // mevcut ("Kış hazırlığı", "Yaz dönemi kontrolü", vs.)
body: "Yaz döneminde klima, soğutma sistemi ve lastik basıncı kontrollerini kayıt altında tutmak faydalı olabilir."

// fuelTypeGuidance (.info) — dizel örneği
title: "Dizel bakım takibi"
body: "Dizel motorlarda DPF (Dizel Partikül Filtresi), enjektör ve yakıt filtresi sağlığı önemlidir. Geçmiş bakımlarını kayda almak takibi kolaylaştırır."

// transmissionGuidance (.warning)
title: "Şanzıman bakım takibi"
body: "Otomatik vitesli araçlarda şanzıman yağı ve filtre değişimi mekanik ömür için kritiktir. Bakım geçmişini kontrol edebilirsin."

// odometerMilestone (.info)
title: "120.000 km eşiği"
body: "Aracın 120.000 km eşiğinde. Bu kilometre aralığında triger seti ve ağır bakımların kontrol edilmesi mekanik ömür için faydalı olabilir."

// monthlyExpensePrompt (.softQuestion)
title: "Bu ay masraf kaydın var mı?"
body: "Bu ay aracın için otoyol geçişi, yıkama veya bakım gibi harcamalar yaptın mı?"

// maintenance (noServiceRecord) (.warning)
title: "Bakım geçmişin eksik"
body: "Kayıtlarına göre bakım geçmişi henüz görünmüyor. İlk bakım kaydını eklemek faydalı olabilir."

// maintenance (oldServiceRecord) (.warning)
title: "Bakım geçmişini gözden geçir"
body: "Son bakım kaydının üzerinden uzun süre geçmiş. Bakım geçmişini kontrol etmek faydalı olabilir."

// missingDocument (.callToAction)
title: "Belge ekle"
body: "Olası bir kontrol veya kaza anında belgelerine hızla erişebilmek için ruhsat fotoğrafını dijital dosyana ekleyebilirsin."

// quietGoodState (.reminder)
title: "Her şey yolunda"
body: "Aracının kayıtları güncel görünüyor. Yeni masraf veya bakım eklersen burada görünür."

// saleFileReadiness (.info)
title: "Satış dosyası hazır mı?"
body: "Aracının satışa hazır olması için en az 1 belge, 1 bakım kaydı ve son km bilgisi gerekiyor. Eksik olanları tamamlayabilirsin."
```

**Acceptance:**
- 13 insight üretim fonksiyonunun hepsi yeni metinleri kullanıyor
- Başlık max 30 karakter, gövde max 120 karakter
- "yap/et/gir/yükle" emri yok
- Teknik terimler parantez içi açıklamalı

---

# Fix 1.1.6 — SwiftData migration

**Karar:** ROADMAP Karar 4.2 açık sorular.

**Dosya:** `Models/VehicleInsight.swift` veya ayrı `Migrations/` klasörü.

**Yapılacak:**

`VehicleInsight` SwiftData `@Model`'i için migration planı:

- **v1 → v2:** `action` alanı zorunlu → opsiyonel
- **Yeni alan:** `contentKind: VehicleInsightContentKind` (default `.info`)
- **Yeni alan:** `snoozeDays: Int?` (default nil)

```swift
// Mevcut kayıtlar için migration:
migrationPlan.append { context in
    let existing = try context.fetch(FetchDescriptor<VehicleInsight>())
    for insight in existing {
        if insight.contentKind == nil {
            insight.contentKind = .callToAction  // mevcut hepsi CTA'ydı
        }
        // action zorunluydu, otomatik kalır
    }
}
```

**Acceptance:**
- Mevcut kayıtlar yeni şemaya migrate olur, veri kaybı yok
- `action` artık opsiyonel, eski kayıtlarda nil değil (geriye uyumlu)

---

# Fix 1.1.7 — DemoDataSeeder: 5 rehber senaryosu

**Karar:** Gemini raporu Bölüm 5.5 + ROADMAP Faz 2.3.

**Dosya:** `Services/DemoDataSeeder.swift`

**Yapılacak:**

Mevcut `seedInsightScenarios()` fonksiyonunu genişlet veya 5 yeni senaryo ekle:

```swift
func seedGuideScenarios(modelContext: ModelContext) {
    let vehicleId = UUID()
    
    // 1. Kritik Eylem — TÜVTÜRK gecikmesi
    let overdueInspection = VehicleInsight(
        type: .overdueReminder,
        contentKind: .callToAction,
        priority: .important,
        title: "Muayene süresi doldu",
        body: "TÜVTÜRK muayene geçerlilik süren tükenmiş görünüyor.",
        action: .openTodos
    )
    
    // 2. Sezonluk Bilgi — BEV kış
    let evWinterInfo = VehicleInsight(
        type: .seasonalGuidance,
        contentKind: .info,
        priority: .info,
        title: "Soğuk hava batarya koruması",
        body: "Hava sıcaklığı düştüğünde bataryayı %20-80 arasında tutmak, lityum hücrelerin ömrünü uzatır.",
        action: .acknowledge,
        snoozeDays: 90
    )
    
    // 3. Mekanik Uyarı — DSG 60K
    let dsgWarning = VehicleInsight(
        type: .transmissionGuidance,
        contentKind: .warning,
        priority: .warning,
        title: "DSG şanzıman yağı",
        body: "Islak kavramalı DSG şanzımanlarda her 60.000 km'de bir yağ ve filtre değişimi mekanik ömür için kritiktir.",
        action: .addServiceRecord,
        snoozeDays: 30
    )
    
    // 4. Pasif Hatırlatma — MTV
    let mtvReminder = VehicleInsight(
        type: .calendarPeriod,
        contentKind: .reminder,
        priority: .info,
        title: "MTV taksit dönemi",
        body: "Motorlu Taşıtlar Vergisi (MTV) ödeme dönemi başladı. Ödedikten sonra masraf olarak kaydedebilirsin.",
        action: .addMTVReminder,
        snoozeDays: 30
    )
    
    // 5. Yumuşak Soru — Aylık masraf
    let expensePrompt = VehicleInsight(
        type: .monthlyExpensePrompt,
        contentKind: .softQuestion,
        priority: .info,
        title: "Bu ay masraf kaydın var mı?",
        body: "Bu ay aracın için otoyol geçişi, yıkama veya bakım gibi harcamalar yaptın mı?",
        action: .addExpense,
        snoozeDays: 30
    )
    
    [overdueInspection, evWinterInfo, dsgWarning, mtvReminder, expensePrompt]
        .forEach { modelContext.insert($0) }
}
```

**Acceptance:**
- 5 senaryo tek tuşla yüklenebilir (Developer Settings UI'ında)
- Her senaryo Garaj ve Araç Detay'da doğru görünür
- DEBUG-only — release'de yer almaz

---

# Fix 1.1.8 — Smoke doğrulama

**Karar:** Tüm Fix 1.1.X'in birleşik doğrulaması.

**Yapılacak:**

1. **Test:** `xcodebuild test -scheme Ruhsatim -destination 'platform=iOS Simulator,name=iPhone 17'`
   - **151+ test geçmeli** (yeni testler eklendiyse daha fazla)
   - Migration testleri eklensin: `VehicleInsightMigrationTests.swift`

2. **Görsel smoke test (dark-only):**
   - Garaj daily summary → 1-3 rehber kartı görünür
   - Araç Detay rehber → tüm 13 insight tipi simüle edilebilir
   - Dismiss butonu → sonraki açılışta kart yok
   - Snooze → 30/60/90 gün sonra tekrar görünür

3. **Kontrol listesi:**
   - [ ] `overdueReminder` kartı: zorunlu CTA, dismiss butonu yok
   - [ ] `seasonalGuidance` kartı: dismiss butonu var, CTA yok
   - [ ] `monthlyExpensePrompt` kartı: çift buton (Masraf Ekle + Şimdi Değil)
   - [ ] Snooze edilmiş kart `insights(...)` çıktısında yok
   - [ ] İkon renkleri doğru (critical/warning/accent)
   - [ ] Başlık ≤ 30 karakter, gövde ≤ 120 karakter
   - [ ] "yap/et/gir/yükle" emri yok

**Acceptance:**
- Tüm testler geçti
- Görsel kontrol listesi ✓
- `git diff` scope: 6-8 dosya (Models, Services x2, DesignSystem, Features x2, Tests). `Configuration/`, `Resources/`, `docs/` dokunulmadı.

---

## Notlar

- Bu prompt **kod tarafında büyük bir refactor** — model değişikliği + 13 metin yeniden yazımı + yeni component. Migration kritik, veri kaybı olmamalı.
- TestFlight internal testing'ten gelen feedback'i dikkate al — kart metinleri kullanıcı testi sonrası tekrar revize edilebilir.
- Bu PR tamamlandığında `ROADMAP.md` Faz 1.1 tamamlandı olarak işaretlenebilir (manifesto güncellemesi ayrı commit).
- Faz 2 (Dosya Skoru, Timeline milestone, vs.) bu PR'dan sonra ayrı sprint'te.