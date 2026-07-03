# Coding Agent Prompt — Arvia v1.1 Ürün & UX İyileştirmeleri

> Bu prompt, MVP submit sonrası (ilk güncelleme / v1.1) için code agent'ın çalıştıracağı **ürün/UX iyileştirmelerini** tarif eder.
> Ön koşul: `docs/CODING_AGENT_PROMPT_MVP_FIXES.md` tamamlanmış, build + test geçmiş, App Store submit yapılmış olmalı.
> Karar manifestosu: `docs/STRATEGIC_DECISIONS_MVP.md` — bu prompt'taki tüm kararlar orada kayıt altında.

---

## Context

Arvia TestFlight/App Store'a gönderildi. İlk gerçek kullanıcı verisi gelmeye başladı. Bu prompt'taki işler **submit sonrası ilk güncelleme** ile gelecek. Sıralama önemli:

1. Önce **3.6 (PDF branding)** ve **3.1 (Checklist Garaj'da)** — küçük işler, hızlı değer, kullanıcıyı direkt etkiler.
2. Sonra **3.4 (Insight test senaryoları)** — test coverage, marketing material.
3. Sonra **3.3 (Milestone timeline)** ve **3.5 (Wizard form)** — daha büyük refactorlar.

Tasarım anayasası `01_DESIGN.md` kanundur. Token-only. AI-slop yasak.

---

## Hard constraints (BUNLARI İHLAL ETME)

- ❌ Yeni özellik ekleme. Sadece bu prompt'ta listelenen işler.
- ❌ Mevcut MVP davranışını değiştirme. Wizard öncesi kullanıcılar tek form ile devam edebilmeli (geri dönüş path).
- ❌ Tasarım token'larını (`AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, `AppShadows`, `ButtonStyles`) değiştirme.
- ❌ SPM dependency ekleme, yeni framework import etme.
- ❌ `Configuration/`, `Resources/`, `build/`, `docs/` (bu dosya dışı) altındaki dosyaları düzenleme.
- ❌ `.xcconfig`, `.xcprivacy`, `.entitlements`, `Info.plist`, `.pbxproj` değiştirme.
- ❌ Mevcut testleri silme/geçersiz kılma. Yeni test ekleme sadece doğrulama için.
- ❌ Mevcut UI davranışını "bu daha iyi" diye değiştirme. Sadece listelenen iş.

## Soft constraints

- Her değişiklik sonrası `xcodebuild test` çalıştır, 89+ test geçmeli.
- Her yeni view için `#Preview` ekle (dark-only tema).
- Magic number YOK. Spacing/renk/radius hep token üzerinden.
- Bu prompt'taki her madde ayrı PR/branch olabilir. Birleştirmek zorunda değilsin.

---

# 1.1 Dosya Tamlığı Checklist — Garaj'a taşı (Karar 3.1)

**Karar:** `docs/STRATEGIC_DECISIONS_MVP.md` 3.1.

**Dosyalar:**
- `Features/Garage/GarageView.swift` (composition)
- `DesignSystem/Components/DosyaniTamamlaChecklist.swift` (mevcut, değişmeyebilir)

**Mevcut durum:** `DosyaniTamamlaChecklist` component'i var. `Features/VehicleDetail/VehicleDetailView.swift` içinde kullanılıyor. Garaj'da **görünmüyor**.

**Yapılacak:**

1. `GarageView.swift` `garageContent` body'sinde, `bugünGarageSection`'dan **sonra**, `quickActionsSection`'dan **önce** checklist'i yerleştir. Veya `bugünGarageSection` içinde, primary insight'in altına secondary section olarak.

Önerilen yerleşim:
```swift
private var garageContent: some View {
    ScrollView {
        VStack(spacing: AppSpacing.lg) {
            // ... hero card ...
            
            if let vehicle = currentVehicle {
                todayGarageSection(vehicle: vehicle)
                
                // YENİ: checklist (sadece eksik kriter varsa)
                if let checklist = dosyaniTamamlaSection(vehicle: vehicle) {
                    checklist
                }
            }
            
            if let vehicle = currentVehicle {
                quickActionsSection(vehicle: vehicle)
            }
            
            // ... rest ...
        }
    }
}
```

2. `dosyaniTamamlaSection(vehicle:)` helper:
```swift
@ViewBuilder
private func dosyaniTamamlaSection(vehicle: Vehicle) -> some View {
    let missing = DosyaniTamamlaChecklist.missingCriteria(for: vehicle, ...)
    if !missing.isEmpty {
        DosyaniTamamlaChecklist(vehicle: vehicle, ...)
            .padding(.horizontal, AppSpacing.screenMarginH)
    }
}
```

3. `DosyaniTamamlaChecklist` component'inin API'si mevcut hâliyle yetersizse (eksik kriterleri dışarıya açmıyorsa) **API'yi genişlet**, mevcut kullanım yerini bozma.

4. Checklist zaten 5 kriterden <5 tamamlandıysa gösterip, hepsi tamamsa gizliyorsa bu davranışı koru. Garaj'da da aynı davranış.

**Acceptance criteria:**

- Araç eklenip muayene/sigorta/ilk masraf/ilk belge girilmediğinde Garaj'da checklist görünür.
- 5 kriter tamamlanınca Garaj'daki checklist gizlenir.
- Araç Detay'daki checklist davranışı değişmez.
- Build + 89 test geçer.

---

# 1.2 Satış Dosyası PDF Branding (Karar 3.6)

**Karar:** `docs/STRATEGIC_DECISIONS_MVP.md` 3.6.

**Dosya:** `Services/PDFExportService.swift`

**Mevcut durum:** PDF üretiliyor, kapak + içerik + disclaimer var. Marka yok.

**Yapılacak:**

1. **Kapak sayfasına footer pill** ekle. Mevcut `drawCoverPage(...)` veya eşdeğer metoda, içeriğin altına:

```swift
// Kapak footer pill
VStack(spacing: 8) {
    HStack(spacing: 6) {
        Image(systemName: "doc.richtext")  // veya arvia ikon
            .font(.caption)
        Text("Arvia ile oluşturuldu")
            .font(.system(size: 10, weight: .medium))
    }
    .foregroundColor(AppColors.textTertiary)
    
    Text("arvia.app")
        .font(.system(size: 9, weight: .regular, design: .monospaced))
        .foregroundColor(AppColors.textTertiary)
}
.padding(.top, 16)
```

2. **Son sayfa** ekle (yeni `drawArviaBrandingPage(...)`):

```swift
// Son sayfa içeriği
VStack(spacing: 24) {
    Spacer()
    
    // Arvia wordmark (text tabanlı, MVP için yeterli)
    HStack(spacing: 8) {
        Image(systemName: "car.fill")
            .font(.system(size: 36, weight: .light))
        Text("Arvia")
            .font(.system(size: 36, weight: .bold))
    }
    .foregroundColor(AppColors.vehicle)
    
    Text("Aracının dijital yaşam dosyası.")
        .font(.system(size: 14))
        .foregroundColor(AppColors.textSecondary)
    
    Spacer().frame(height: 24)
    
    // App Store link placeholder
    // App Store URL'si submit sonrası manuel tamamlanacak
    let appStoreURL = "https://apps.apple.com/app/arvia/PLACEHOLDER"
    
    VStack(spacing: 4) {
        Text("Arvia'yı indir")
            .font(.system(size: 12, weight: .medium))
        Text(appStoreURL)
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(AppColors.accentPrimary)
    }
    
    Spacer()
}
.padding(40)
```

3. `URL(string:)` ile linki parse edip `PDFAction` veya text olarak ekle (PDF link annotation veya düz metin; MVP için düz metin yeterli).

4. `PDFExportService.swift` içinde bir static constant tanımla:

```swift
enum PDFExportService {
    // ... mevcut ...
    
    /// App Store URL — submit sonrası manuel tamamlanacak
    /// TODO: Submit onayından sonra gerçek App Store ID ile değiştir
    static let appStoreURL = "https://apps.apple.com/app/arvia/PLACEHOLDER"
}
```

5. **Disclaimer sayfası** zaten varsa, ondan **sonra**, **branding sayfasından önce** değil, doğrudan son sayfa olarak branding gelsin. (Veya disclaimer'ı kapağın altına taşı, branding son sayfa olsun — senin takdirin, önemli olan marka görünürlüğü.)

**Acceptance criteria:**

- PDF oluşturulduğunda kapakta "Arvia ile oluşturuldu" + "arvia.app" görünür.
- Son sayfada Arvia wordmark + tagline + App Store placeholder link görünür.
- Tüm sayfaların footer'ında "Arvia ile oluşturuldu" pill'i (çok küçük, sade).
- Mevcut disclaimer ve içerik sayfaları değişmez.
- Build + 89 test geçer.

---

# 2.1 Araç Yaşam Çizgisi: Milestone Kartları (Karar 3.3)

**Karar:** `docs/STRATEGIC_DECISIONS_MVP.md` 3.3.

**Dosyalar:**
- `Features/VehicleDetail/VehicleDetailView.swift` (mevcut `lifeTimelineSection`)
- `Features/VehicleDetail/VehicleDetailMilestoneCard.swift` (YENİ)

**Yapılacak:**

1. Yeni component `VehicleDetailMilestoneCard`:

```swift
struct VehicleDetailMilestoneCard: View {
    enum MilestoneKind {
        case purchase       // araç satın alma
        case majorService   // ilk büyük bakım (parts_cost > 5000)
        case inspection     // ekspertiz raporu
        case saleFile       // satış dosyası
        case ownershipYear  // 5+ yıl sahiplik
    }
    
    let kind: MilestoneKind
    let date: Date
    let title: String
    let subtitle: String?
    let icon: String
    let accent: Color  // .accentPrimary, .vehicle, .success
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.25), lineWidth: 2)
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(accent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                }
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(accent.opacity(0.3), lineWidth: 1.5)
        )
    }
}
```

2. `lifeTimelineSection` içinde event'leri milestone kriterlerine göre değerlendir:

```swift
// Mevcut events listesi
let allEvents = buildTimelineEvents(vehicle: vehicle, ...)

// Event'leri milestone / regular olarak ayır
let milestoneEvents = allEvents.filter { isMilestone($0) }
let regularEvents = allEvents.filter { !isMilestone($0) }
```

`isMilestone` helper'ı:
- `.purchase` → vehicle.purchaseDate != nil
- `.majorService` → service.partsCost > 5000 VEYA service.serviceType == .major
- `.inspection` → any inspectionReport
- `.saleFile` → any saleFile
- `.ownershipYear` → owned > 5 yıl

3. Render: VStack içinde sırayla milestone + regular event'leri göster. Milestone'lar arasında ince Divider, regular'lar arasında timeline noktası.

4. Mevcut timeline davranışını **bozma** — sadece milestone olan event'ler özel kart alıyor.

**Acceptance criteria:**

- Araç eklenip purchaseDate set edilince → satın alma milestone kartı görünür.
- İlk büyük bakım (parts_cost > 5000) eklenince → majorService milestone kartı görünür.
- Ekspertiz eklenince → inspection milestone kartı görünür.
- Diğer event'ler mevcut sade liste hali.
- Build + 89 test geçer.

---

# 2.2 Insight Test Senaryoları (Karar 3.4)

**Karar:** `docs/STRATEGIC_DECISIONS_MVP.md` 3.4.

**Dosyalar:**
- `Services/DemoDataSeeder.swift` (mevcut, genişletilecek)
- `Features/Settings/SettingsView.swift` (Developer section'a menü)

**Mevcut durum:** `DemoDataSeeder.seed(context:)` zaten var (`-ArviaSeedDemoData` argümanı ile çalışıyor). Developer section var (`#if DEBUG`).

**Yapılacak:**

1. `Services/DemoDataSeeder.swift` içine enum + 5 senaryo ekle:

```swift
enum InsightScenario: String, CaseIterable, Identifiable {
    case empty
    case singleReminder
    case overdueState
    case busyState
    case quietGood
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .empty: return "Boş (hiç araç yok)"
        case .singleReminder: return "Tek hatırlatıcı (sakin)"
        case .overdueState: return "Gecikmiş hatırlatıcı"
        case .busyState: return "Yoğun state (5 hatırlatıcı)"
        case .quietGood: return "Sessiz iyi hal"
        }
    }
    
    var icon: String { ... }  // her senaryo için SF Symbol
    var description: String { ... }
}
```

2. Her senaryo için seed fonksiyonu:

```swift
static func seedInsightScenario(_ scenario: InsightScenario, context: ModelContext) {
    // Önce tüm mevcut veriyi temizle
    clearAll(context: context)
    
    switch scenario {
    case .empty:
        break  // sadece temizle
        
    case .singleReminder:
        let vehicle = makeVehicle(...)
        context.insert(vehicle)
        let reminder = makeReminder(vehicleId: vehicle.id, dueDate: .now.adding(months: 3), type: .inspection)
        context.insert(reminder)
        
    case .overdueState:
        let vehicle = makeVehicle(...)
        context.insert(vehicle)
        let reminder = makeReminder(vehicleId: vehicle.id, dueDate: .now.adding(days: -10), type: .insurance, priority: .critical)
        context.insert(reminder)
        
    case .busyState:
        let vehicle = makeVehicle(...)
        context.insert(vehicle)
        let r1 = makeReminder(vehicleId: vehicle.id, dueDate: .now.adding(days: -5), type: .inspection, priority: .critical)
        let r2 = makeReminder(vehicleId: vehicle.id, dueDate: .now, type: .oil)
        let r3 = makeReminder(vehicleId: vehicle.id, dueDate: .now.adding(months: 1), type: .tire)
        let r4 = makeReminder(vehicleId: vehicle.id, dueDate: .now.adding(months: 3), type: .brake)
        let r5 = makeReminder(vehicleId: vehicle.id, dueDate: .now.adding(months: 6), type: .battery)
        [r1, r2, r3, r4, r5].forEach { context.insert($0) }
        
    case .quietGood:
        let vehicle = makeVehicle(...)
        context.insert(vehicle)
        let reminder = makeReminder(vehicleId: vehicle.id, dueDate: .now.adding(months: 2), type: .inspection, status: .completed, completedAt: .now)
        context.insert(reminder)
    }
    
    try? context.save()
}

private static func clearAll(context: ModelContext) {
    // Tüm model tiplerini fetch + delete
    if let vehicles = try? context.fetch(FetchDescriptor<Vehicle>()) {
        for v in vehicles { context.delete(v) }
    }
    // ... aynısı Reminder, Expense, ServiceRecord, VehicleDocument, InspectionReport, SaleFile için
    try? context.save()
}
```

3. `SettingsView.swift` `developerSection` içine submenu ekle:

```swift
private var developerSection: some View {
    Section {
        // ... mevcut dev seçenekleri ...
        
        Menu {
            ForEach(InsightScenario.allCases) { scenario in
                Button {
                    DemoDataSeeder.seedInsightScenario(scenario, context: modelContext)
                } label: {
                    Label(scenario.displayName, systemImage: scenario.icon)
                }
            }
        } label: {
            Label("Insight Senaryoları", systemImage: "lightbulb")
        }
    } header: {
        Text("Geliştirici")
    } footer: {
        Text("Senaryo seçilince tüm mevcut veri temizlenir. Sadece DEBUG build'de görünür.")
    }
}
```

4. Senaryo seçilince Garaj sekmesine navigate: bunu mevcut `AppNavigationRouter` üzerinden yap veya `selection` binding'i değiştir. Basitçe: senaryo seed'lendikten sonra `navigationRouter.selectedTab = .garage` çağır.

**Acceptance criteria:**

- Settings → Developer → "Insight Senaryoları" → 5 seçenek görünür.
- Her senaryo seçilince:
  - Mevcut tüm veri temizlenir.
  - Senaryo state'i kurulur.
  - Garaj sekmesine dönülür.
  - Garaj ve Araç Detay doğru insight'ları gösterir.
- Release build'de bu menü görünmez (`#if DEBUG` zaten var).
- Mevcut `-ArviaSeedDemoData` argümanı bozulmaz.
- Build + 89 test geçer.

---

# 2.3 Onboarding → Araç Ekle Wizard (Karar 3.5)

**Karar:** `docs/STRATEGIC_DECISIONS_MVP.md` 3.5.

**Dosyalar:**
- `Features/Garage/VehicleFormView.swift` (mevcut, korunur)
- `Features/Garage/VehicleFormWizardView.swift` (YENİ)

**Mevcut durum:** `VehicleFormView` 6 section, tek scroll form. Onboarding sonrası açıldığında 18 alan.

**Yapılacak:**

1. Yeni `VehicleFormWizardView`:

```swift
struct VehicleFormWizardView: View {
    enum WizardStep: Int, CaseIterable, Identifiable {
        case identity = 0      // Tanımla
        case condition = 1     // Durumu
        case upcoming = 2      // Sıradaki işler
        
        var id: Int { rawValue }
        
        var title: LocalizedStringKey {
            switch self {
            case .identity: return "Tanımla"
            case .condition: return "Durumu"
            case .upcoming: return "Sıradaki işler"
            }
        }
    }
    
    @State private var currentStep: WizardStep = .identity
    
    // Shared form state — VehicleFormView'daki state'lerin aynısı
    // (araç türü, plaka, marka, model, yıl, km, yakıt, vites, vb.)
    @State private var vehicleType: VehicleType = .car
    @State private var plate = ""
    @State private var brand = ""
    // ... diğer tüm state'ler ...
    
    // Upcoming step state
    @State private var addInspectionReminder = false
    @State private var inspectionDate: Date = ...
    @State private var addInsuranceReminder = false
    @State private var addMTVReminder = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var paywallService: PaywallService
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressIndicator
                
                Group {
                    switch currentStep {
                    case .identity: identityStep
                    case .condition: conditionStep
                    case .upcoming: upcomingStep
                    }
                }
                .transition(.opacity)
                
                Spacer()
                
                navigationButtons
            }
            .background(Color.appBackground)
            .navigationTitle(currentStep.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }
    
    // ... step views, save logic ...
}
```

2. **Step 1 (Identity):**
   - Araç türü picker
   - Plaka
   - Marka picker + özel
   - Model picker + özel
   - Yıl

3. **Step 2 (Condition):**
   - Güncel km
   - Yakıt tipi
   - Vites tipi
   - Kullanım tipi
   - Fotoğraf (PhotosPicker)

4. **Step 3 (Upcoming):**
   - 3 toggle + tarih seçici:
     - "Muayene hatırlatıcısı ekle" (default 2 yıl sonra)
     - "Trafik sigortası hatırlatıcısı ekle" (default 1 yıl sonra)
     - "MTV hatırlatıcısı ekle" (yılın 1. veya 2. yarısı — bugünkü mantık)
   - Skip seçeneği (default: hepsi uncheck)

5. **Progress indicator** — üstte:

```swift
private var progressIndicator: some View {
    HStack(spacing: AppSpacing.xs) {
        ForEach(WizardStep.allCases) { step in
            Capsule()
                .fill(step.rawValue <= currentStep.rawValue ? AppColors.accentPrimary : AppColors.border)
                .frame(height: 3)
        }
    }
    .padding(.horizontal, AppSpacing.screenMarginH)
    .padding(.vertical, AppSpacing.sm)
}
```

6. **Navigation buttons:**

```swift
private var navigationButtons: some View {
    HStack(spacing: AppSpacing.sm) {
        if currentStep != .identity {
            Button("Geri") {
                withAnimation { currentStep = WizardStep(rawValue: currentStep.rawValue - 1) ?? .identity }
            }
            .buttonStyle(.secondary)
        }
        
        if currentStep != .upcoming {
            Button("Devam") {
                withAnimation { currentStep = WizardStep(rawValue: currentStep.rawValue + 1) ?? .upcoming }
            }
            .buttonStyle(.primary)
            .disabled(!canContinue)
        } else {
            Button(addInspectionReminder || addInsuranceReminder || addMTVReminder ? "Aracı Ekle" : "Atla ve Ekle") {
                saveVehicle()
            }
            .buttonStyle(.primary)
        }
    }
    .padding(.horizontal, AppSpacing.screenMarginH)
    .padding(.vertical, AppSpacing.md)
}

private var canContinue: Bool {
    switch currentStep {
    case .identity:
        return !plate.trimmingCharacters(in: .whitespaces).isEmpty
    case .condition:
        return true  // tüm alanlar opsiyonel
    case .upcoming:
        return true
    }
}
```

7. **Save logic** — `VehicleFormView.saveVehicle()` ile aynı iş, ek olarak step 3'teki seçili reminder'ları oluştur.

8. **Mevcut `VehicleFormView` korunur** — başka yerlerden (Garaj menüsü "Araç Ekle", vb.) çağrılabilir. **WIZARD SADECE onboarding sonrası** `OnboardingGate` flow'unda kullanılır.

9. **Onboarding sonrası akış** — `OnboardingView.completeOnboarding()` veya `VehicleDossierApp.swift` içindeki `.onChange(of: onboardingCompleted)` handler'ı:
   - Eğer kullanıcı **ilk kez** onboarding tamamlıyorsa (yani vehicle count = 0) → `VehicleFormWizardView` aç.
   - Yoksa (test/dev ortamında birden fazla kez) → eski `VehicleFormView` korunur.

Bu kontrol `vehicleCount` üzerinden yapılabilir:
```swift
let vehicleCount = (try? context.fetch(FetchDescriptor<Vehicle>()).count) ?? 0
showPostOnboardingSheet = vehicleCount == 0 ? .wizard : .legacyForm
```

**Acceptance criteria:**

- Onboarding → "İlk aracımı ekle" → wizard step 1 açılır.
- Step 1'de plaka boşken "Devam" disabled.
- Step 1'de plaka girilip "Devam" → step 2.
- Step 2'de tüm alanlar opsiyonel; "Devam" her zaman aktif.
- Step 3'te hiçbir şey seçmeden "Atla ve Ekle" → sadece araç kaydedilir.
- Step 3'te "Muayene" seçilip "Aracı Ekle" → araç + muayene hatırlatıcısı kaydedilir.
- iOS back gesture wizard'da bir adım geri gider.
- Mevcut `VehicleFormView` korunur, Garaj menüsünden hâlâ açılır.
- Build + 89 test geçer.

---

# Test & validation

Tüm işler bittikten sonra:

1. **Build:** `xcodebuild -project VehicleDossierApp.xcodeproj -scheme VehicleDossierApp -destination 'platform=iOS Simulator,name=iPhone 15' build`.
2. **Testler:** `xcodebuild test`. 89+ test geçmeli.
3. **Manuel smoke (simulator):**
   - Onboarding → wizard 3 adım → araç kaydedilir.
   - Onboarding skip → wizard 3 adım.
   - Garaj → "Araç Ekle" → eski form (VehicleFormView) açılır.
   - Settings → Developer → "Insight Senaryoları" → 5 senaryo tek tek dene.
   - Araç Detay → Timeline → milestone'lar görünür.
   - Sale File → PDF oluştur → "Arvia ile oluşturuldu" footer görünür, son sayfa branding görünür.

---

# Deliverable (agent'ın çıktısı)

İş bittiğinde rapor ver:

- Değişen dosyaların listesi, her dosya için 1 satır açıklama.
- 5 maddeden hangileri tamam (checkbox ✅).
- Build ve test sonucu.
- Spec'ten sapma varsa gerekçesi.
- Yeni ortaya çıkan TODO varsa listele.
- App Store URL placeholder'ı manuel tamamlanacak — bunu açıkça yaz.

---

# File map (hızlı referans)

```
Features/
  Garage/
    GarageView.swift                    (1.1 — checklist ekle)
    VehicleFormView.swift               (korunur)
    VehicleFormWizardView.swift         (2.3 — YENİ)
  VehicleDetail/
    VehicleDetailView.swift             (2.1 — milestone entegrasyonu)
    VehicleDetailMilestoneCard.swift    (2.1 — YENİ)
  Settings/
    SettingsView.swift                  (2.2 — Developer menü)
  ...
Services/
  PDFExportService.swift                (1.2 — Arvia branding)
  DemoDataSeeder.swift                  (2.2 — 5 senaryo)
DesignSystem/
  Components/
    DosyaniTamamlaChecklist.swift       (1.1 — API genişletme gerekebilir)
```

---

# Son notlar

- Token'lara dokunma. Anayasa kuralları.
- Yeni component ekliyorsan `DesignSystem/Components/` altına; feature-local helper'ı feature içinde tut.
- Preview'ları (normal + dark) ekle.
- Türkçe metin ekleyeceksen kısa ve anayasadaki tona uygun olsun.
- App Store URL placeholder'ı submit sonrası manuel tamamlanacak — unutma.

Kolay gelsin.
