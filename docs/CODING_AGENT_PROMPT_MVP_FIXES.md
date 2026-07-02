# Coding Agent Prompt — Arvia MVP Öncesi & v1.1 Refactor

> Bu dosya, code agent'ın (Cursor / Claude Code / benzer) çalıştıracağı **iki öncelikli düzeltme paketini** tarif eder.
> Amacı: test öncesi sağlamlaştırmak + ilk güncellemede temizleyerek geliştirme hızını korumak.
> Yeni özellik ekleme. Tasarım anayasasına dokunma. Mevcut testleri kırma.

---

## Context

Arvia, SwiftUI + SwiftData ile yazılmış, local-first bir iOS uygulaması. Tasarım anayasası `01_DESIGN.md`, ürün kapsamı `02_PRODUCT_SCOPE.md`, mimari `03_SWIFTUI_ARCHITECTURE.md` içinde. Şu anda **TestFlight öncesi** — `Supabase SQL manuel çalıştırılacak`, hesap silme, paywall, hukuk linkleri tamam. `lastchecks.md` mevcut durumu özetliyor.

Build: `VehicleDossierApp.xcodeproj`. 89 test geçiyor. SwiftData container local. CloudKit/Supabase feature flag kapalı (`AppEnvironment.swift`). Debug'da paywall dev-mode UserDefaults ile çalışıyor; release'de StoreKit 2 devreye giriyor.

---

## Hard constraints (BUNLARI İHLAL ETME)

- ❌ Yeni feature ekleme. Sadece BUCKET 1 ve BUCKET 2'de listelenen işler.
- ❌ Tasarım token'larını değiştirme (`AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, `AppShadows`, `ButtonStyles`). Ham hex, custom radius, farklı spacing **yok**.
- ❌ Tasarım anayasasının yasakladığı desenleri sokma (gradient çorbası, opacity yığını, generic SaaS kart grid).
- ❌ SPM dependency ekleme. Yeni framework import etme.
- ❌ `Configuration/`, `Resources/`, `build/`, `docs/` (bu dosya dışı) altındaki dosyaları düzenleme.
- ❌ `.xcconfig`, `.xcprivacy`, `.entitlements`, `Info.plist`, `.pbxproj` değiştirme.
- ❌ Supabase SQL, RLS, Edge Function dosyalarını değiştirme.
- ❌ Mevcut testleri silme veya geçersiz kılma. Yeni test ekleme SADECE bug fix doğrulamak için gerekirse.
- ❌ Türkçe kullanıcı metnini İngilizce'ye çevirme. Mevcut metin aynen kalır.

## Soft constraints

- Mümkün olduğunca küçük, izole patch yap. Tek PR'da 10 ayrı concern olmasın.
- Yeni helper ekliyorsan, design system'in parçası olacak şekilde `DesignSystem/Components/` altına koy. Feature-local helper'ı feature içinde tut.
- Her değişiklik sonrası mevcut `Tests/` altındaki testleri çalıştır, regression olmadığını doğrula.

---

# BUCKET 1 — Pre-MVP (TestFlight öncesi tamamlanmalı)

> Kullanıcı deneyimini veya App Store review sürecini doğrudan etkileyen bug'lar. Bunlar bitmeden submit etme.

## 1.1 PaywallFeature context expansion

**Dosya:** `Features/Paywall/PaywallView.swift`

**Mevcut durum:** `PaywallFeature` enum'unda sadece `case secondVehicle` var. Hero başlığı, alt metin, üst özellik listesi hep "çoklu araç" çerçevesinde. `PaywallService.FreeLimits` zaten başka gate'leri de tanımlıyor (`documentLimit`, `saleFileRequiresPro`, `advancedReportsRequiresPro`, `inspectionReportsRequirePro`) — UI bağlandığı an paywall metni yanlış context gösterecek.

**Yapılacak:**

`PaywallFeature` enum'unu genişlet:

```swift
enum PaywallFeature {
    case secondVehicle
    case documentLimit
    case saleFileExport
    case advancedReports
    case inspectionReport

    var title: LocalizedStringKey { ... }       // hero title
    var subtitle: LocalizedStringKey { ... }    // hero description
    var topBenefits: [(icon: String, title: String)] { ... }  // 3 maddelik spotlight listesi
}
```

Her case için:

| Case | Title | Subtitle | Top benefits |
|------|-------|----------|--------------|
| `.secondVehicle` | "Birden fazla aracı tek garajda yönet" | Mevcut açıklama | car.2 / Sınırsız araç; rectangle.grid.2x2 / Çoklu araç garajı; bell.badge / Tüm araçlar için hatırlatıcılar |
| `.documentLimit` | "Sınırsız belge kasası" | "Aracın tüm belgelerini — ruhsat, poliçe, fatura, ekspertiz — tek kasada sakla. Arvia Pro ile sınır olmadan ekle." | doc.text / Sınırsız belge; folder / Araç bazlı belge kasası; doc.text.magnifyingglass / Hızlı belge önizleme |
| `.saleFileExport` | "Sınırsız satış dosyası" | "Aracını satarken bakım ve belge geçmişini paylaşılabilir PDF olarak hazırla. Arvia Pro ile sınırsız kez oluştur." | doc.richtext / Sınırsız satış dosyası; square.and.arrow.up / Hızlı paylaşım; qrcode / (placeholder) |
| `.advancedReports` | "Gelişmiş raporlar" | "Yıllık, aylık ve km bazlı maliyet analizleriyle aracının gerçek sahiplik maliyetini gör." | chart.bar / Gelişmiş raporlar; chart.line.uptrend.xyaxis / Trend analizi; tablecells / Kategori dağılımı |
| `.inspectionReport` | "Ekspertiz raporları" | "TÜVTÜRK veya bağımsız ekspertiz raporlarını aracının dosyasına ekle. Arvia Pro ile sınırsız." | magnifyingglass / Sınırsız ekspertiz kaydı; doc.text.magnifyingglass / Rapor doğrulama; qrcode / (placeholder) |

`heroSection`, `topBenefits` değerini kullansın. Aşağıdaki tam `PaywallService.proFeatures` listesi (`proBenefits`) olduğu gibi kalsın — bunlar ekstra.

`GarageView`'daki mevcut `.secondVehicle` çağrılarına dokunma. Yeni gate'ler ileride bağlanacak.

**Acceptance criteria:**

- Beş case'in hepsi derlenir.
- `PaywallView(feature: .documentLimit)` önizlemesi hero'da farklı başlık + açıklama + 3 farklı top benefit gösterir.
- "Pro ile Gelenler" tam listesi (aşağıda) hâlâ `PaywallService.proFeatures` üzerinden gelir; değişmez.
- Free/Pro karşılaştırma tablosu değişmez.

## 1.2 Paywall badge — StoreKit metadata'sından oku

**Dosya:** `Features/Paywall/PaywallView.swift` (line 79 civarı)

**Mevcut durum:** Badge product ID substring match'ine bakıyor: `product.id.contains("yearly") ? "En Avantajlı" : (product.id.contains("lifetime") ? "Tek Seferlik" : nil)`. App Store Connect'te ID değişirse sessizce düşer.

**Yapılacak:**

Her `Product` için StoreKit'in verdiği metadata'dan karar ver:

- `product.subscription?.subscriptionPeriod.unit == .year` → "En Avantajlı"
- `product.type == .nonConsumable` (lifetime buraya düşer) → "Tek Seferlik"
- Aksi → `nil`

Subscription info gelmezse (defensive) `nil` döndür; mevcut fallback davranışını koru.

DEBUG'taki dev-mode fallback (line 64-68) **dokunma** — orada StoreKit ürünü yok, manuel listeyle çalışıyor.

**Acceptance criteria:**

- `product.id.contains(...)` çağrıları bu dosyadan tamamen kalkar (DEBUG fallback hariç).
- DEBUG'ta 3 ürün için doğru badge'ler görünür.

## 1.3 ReminderFormView validasyon sırası

**Dosya:** `Features/Reminders/ReminderFormView.swift` (line 291-307)

**Mevcut durum:** `customTitle` boşsa ve araç seçilmemişse sadece araç hatası gösterilir. Kullanıcı hata gizlenir.

**Yapılacak:** Validasyonları tek `errors` array'inde topla, sonra `guard errors.isEmpty` ile çık.

```swift
private func saveReminder() {
    var errors: [String] = []

    if selectedTemplate == .custom && customTitle.trimmingCharacters(in: .whitespaces).isEmpty {
        errors.append("Hatırlatıcı adı girmelisin.")
    }
    if selectedVehicleId == nil {
        errors.append("Bir araç seçmelisin.")
    }

    guard errors.isEmpty else {
        validationErrors = errors
        return
    }

    // selectedVehicleId artık kesin; force unwrap etmeden al
    guard let vehicleId = selectedVehicleId else { return }

    // ... mevcut insert/update logic aynen
}
```

`errorSection`'daki render'a dokunma, sadece içerideki error dizisini kullanır.

**Acceptance criteria:**

- Custom title boş + araç seçilmemiş → 2 hata satırı görünür.
- Normal save akışı bozulmaz.

## 1.4 Sayısal klavye düzeltmesi (Türkçe ayırıcı)

**Etkilenen dosyalar:**

- `Features/Garage/VehicleFormView.swift` (year, odometer, lastServiceOdometer)
- `Features/Reminders/ReminderFormView.swift` (dueOdometerText)
- Quick odometer update sheet (ara; muhtemelen `Features/Reminders/` veya `Features/VehicleDetail/` altında)
- Aynı pattern'i kullanan diğer Int/Double alanları

**Mevcut durum:** `.keyboardType(.numberPad)` Türkçe binlik ayırıcı (nokta) kabul etmiyor.

**Yapılacak:**

- `.numberPad` → `.decimalPad` (tüm Int alanları için). Decimal pad'de nokta var; kullanıcı "192.000" yazabilir.
- Parse ederken nokta + virgülü temizle:

```swift
let raw = odometerText.trimmingCharacters(in: .whitespaces)
let cleaned = raw.replacingOccurrences(of: ".", with: "")
                 .replacingOccurrences(of: ",", with: "")
let value = Int(cleaned)
```

- Display format'a dokunma; `currentOdometer.formatted()` zaten lokalizasyonu doğru basıyor.

**Acceptance criteria:**

- "192.000" → 192000 olarak kaydedilir.
- "192000" → 192000 olarak kaydedilir.
- Saved value hâlâ `Int`.

## 1.5 GarageView multi-vehicle swipe — sağlamlaştır

**Dosya:** `Features/Garage/GarageView.swift` (line 200-211 ve takip eden page indicator)

**Mevcut durum:** `TabView(selection:).page(indexDisplayMode: .never)`, `id: \.offset`, hard-coded 414pt frame. Araç silinince SwiftUI diff'i bozulur; page mode dikey scroll ile edge gesture çakışması riski.

**Yapılacak:**

1. State'i değiştir: `activeVehicleIndex: Int` → `activeVehicleId: UUID?`.
2. `TabView` bloğunu `ScrollView(.horizontal)` + paging ile değiştir:

```swift
if activeVehicles.count > 1 {
    ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: AppSpacing.md) {
            ForEach(activeVehicles) { vehicle in
                NavigationLink {
                    VehicleDetailView(vehicle: vehicle)
                } label: {
                    heroCardContent(vehicle: vehicle)
                }
                .buttonStyle(PlainCardButtonStyle())
                .containerRelativeFrame(.horizontal)
            }
        }
        .scrollTargetLayout()
    }
    .scrollTargetBehavior(.viewAligned)
    .scrollPosition(id: $activeVehicleId)
    .frame(height: <dynamicHeight>)
    .padding(.horizontal, AppSpacing.screenMarginH)
}
```

3. `activeVehicleId`'den aktif index'i computed property olarak türet: `private var activeVehicleIndex: Int { activeVehicles.firstIndex { $0.id == activeVehicleId } ?? 0 }`. Bu index'i page indicator için kullan.
4. `handleNotificationRoute(_:)` zaten `vehicleId` üzerinden çalışıyor — sadece state'e set et: `activeVehicleId = vehicleId`.
5. `onChange(of: activeVehicles.count)` içinde `activeVehicleId`'yi valide et: listede yoksa ilk araca set et.
6. Yüksekliği sabit 414pt'ten çıkar: `heroCardInner` içeriğine göre `GeometryReader` veya `containerRelativeFrame` ile oransal yap. Veya `.aspectRatio(3/4, contentMode: .fit)` gibi bir yaklaşım kullan.

**Acceptance criteria:**

- Çoklu araçta yatay kaydırma düzgün çalışır.
- Araç silindiğinde stale state kalmaz; UI anasayfaya dönmez, doğru aracı gösterir.
- Notification deep-link doğru araca kayar.
- Page indicator (custom dots) hâlâ doğru senkronize.

## 1.6 EmptyStateView accessibility

**Dosya:** `DesignSystem/Components/EmptyStateView.swift` (line 64-65)

**Mevcut durum:** `.accessibilityElement(children: .combine).accessibilityLabel(title)` — action butonunun affordance'ı VoiceOver'da kaybolur.

**Yapılacak:**

- `.accessibilityElement(children: .combine)` satırını kaldır.
- Title'a `.accessibilityAddTraits(.isHeader)` ekle.
- Description'ı olduğu gibi bırak.
- Action button kendi text label'ıyla zaten accessible.
- Aynı düzeltmeyi `ErrorStateView`'a da uygula.

**Acceptance criteria:**

- VoiceOver: title (header) → description → "Araç Ekle, button".
- Görsel UI değişmez.

## 1.7 Reminder predicate — enum'dan türet

**Dosyalar:** `Features/Records/HistoryView.swift` (line 17), `Features/Garage/GarageView.swift` (line 14)

**Mevcut durum:** `#Predicate<Reminder> { $0.statusRaw == "Tamamlandı" }` veya `$0.statusRaw != "completed"`. Enum rename edilirse sessizce bozulur.

**Yapılacak:**

1. `Models/Reminder.swift` içine static helper'lar ekle:

```swift
extension Reminder {
    static let completedStatusRawValue = ReminderStatus.completed.rawValue
    static let archivedStatusRawValue = ReminderStatus.archived.rawValue
    static let activeStatusRawValue = ReminderStatus.active.rawValue
}
```

2. Predicate'lerde hard-coded string yerine bunları kullan:

```swift
@Query(filter: #Predicate<Reminder> {
    $0.statusRaw != Reminder.completedStatusRawValue
}, sort: \Reminder.dueDate)
```

3. Tüm `statusRaw` karşılaştırmalarını grep ile bul, helper üzerinden yaz.

**Acceptance criteria:**

- "Tamamlandı", "completed" gibi hard-coded string'ler feature kodunda kalmaz (sadece `Enums.swift` içinde olur).
- HistoryView'in `completedReminders` query'si aynı sonuçları döner.
- GarageView'in `activeReminders` query'si aynı sonuçları döner.

## 1.8 OnboardingGate `dismiss()` doğruluğu

**Dosyalar:** `Features/Onboarding/OnboardingView.swift`, `App/VehicleDossierApp.swift`

**Mevcut durum:** OnboardingView modal presented değil, OnboardingGate'in if/else içinde. `completeOnboarding()` `dismiss()` çağırıyor ama yanlış context'te dismiss edebilir (veya no-op olur). Ayrıca `showAddVehicle` OnboardingView'in kendi state'inde — sheet, OnboardingView unmount olurken yaşamıyor olabilir.

**Yapılacak:**

1. `OnboardingView.swift`'teki `completeOnboarding()` sadeleşsin:

```swift
private func completeOnboarding() {
    onboardingCompleted = true
    // dismiss() çağrısı YOK
    // showAddVehicle = true çağrısı YOK
}
```

2. `OnboardingView` body'sinden `.sheet(isPresented: $showAddVehicle) { VehicleFormView() }` kaldır.
3. `OnboardingView`'in `showAddVehicle` state'ini sil.
4. `VehicleDossierApp.swift`'te onboarding tamamlanmasını observe et ve sheet'i orada aç:

```swift
@State private var showPostOnboardingAddVehicle = false

// body içinde
OnboardingGate {
    BrandIntroView {
        AppRouter()
    }
    .modelContainer(modelContainer)
    .environmentObject(...)
    // ...
}
.onChange(of: onboardingCompleted) { _, completed in
    if completed && !showPostOnboardingAddVehicle {
        // Küçük gecikme: gate swap animasyonu bitsin
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showPostOnboardingAddVehicle = true
        }
    }
}
.sheet(isPresented: $showPostOnboardingAddVehicle) {
    VehicleFormView()
}
```

5. `onboardingCompleted` okumak için `VehicleDossierApp` struct'ında `@AppStorage("onboarding_completed") private var onboardingCompleted = false` ekle. OnboardingGate da aynı anahtarı okuduğu için store senkronize kalır.

**Acceptance criteria:**

- İlk açılışta onboarding → "İlk aracımı ekle" tap → onboarding kaybolur, sonra VehicleFormView sheet açılır.
- Onboarding skip (Atla) → aynı davranış.
- İkinci açılışta (zaten tamamlanmış) hiçbir şey göstermez.
- Geri tuşu (sheet dismiss) düzgün çalışır.

## 1.9 App Privacy labels mutabakatı (manuel checklist)

**Dosya:** Bu yeni bir markdown checklist'i oluştur: `docs/PRIVACY_LABELS_RECONCILIATION.md`.

**Yapılacak:**

Agent sadece dosyayı yazar; App Store Connect input'u kullanıcı tarafından yapılacak.

`Resources/PrivacyInfo.xcprivacy` içeriğini oku ve her `NSPrivacyCollectedAPIType`/`NSPrivacyAccessedAPIType` girdisini tabloya yaz:

| PrivacyInfo key | Veri türü | App Store sorusu | Önerilen yanıt | Amaç string'i | Retention |
|-----------------|-----------|------------------|----------------|---------------|-----------|
| ... | ... | ... | Yes/No | ... | ... |

Boş bırakılan alanlar (örn. `NSPrivacyTrackingDomains` boş) için "Bu veri toplanmıyor, App Store'da 'No, I do not collect data from this app' seçilebilir" notu düş.

`docs/lastchecks.md` madde 8'e atıf ver; oradaki "Supabase domain listesi eklenmedi" notunu da tabloya yansıt.

**Acceptance criteria:**

- `docs/PRIVACY_LABELS_RECONCILIATION.md` dosyası oluşur.
- Her PrivacyInfo girdisi için App Store sorusu eşleştirilir.
- Kod değişikliği yok.

---

# BUCKET 2 — v1.1 refactor (ilk güncelleme)

> Bug' değil ama geliştirme hızını yavaşlatan veya accessibility'de hafif sorunlu kod. MVP sonrası tek PR'da gönderilebilir.

## 2.1 VehicleDetailView modüler bölünmesi

**Dosya:** `Features/VehicleDetail/VehicleDetailView.swift` (2114 satır)

**Yapılacak:** Logical section'ları ayrı dosyalara çıkar:

- `Features/VehicleDetail/VehicleDetailView.swift` (composition + body, <500 satır hedef)
- `Features/VehicleDetail/VehicleDetailHero.swift` (hero header kartı)
- `Features/VehicleDetail/VehicleDetailCurrentStatus.swift` (currentStatusSection, nextTasksCard)
- `Features/VehicleDetail/VehicleDetailFileCompleteness.swift` (fileCompletenessCard + score logic)
- `Features/VehicleDetail/VehicleDetailArviaGuide.swift` (guide insights)
- `Features/VehicleDetail/VehicleDetailTimeline.swift` (lifeTimelineSection)
- `Features/VehicleDetail/VehicleDetailDocuments.swift` (documentsSection)
- `Features/VehicleDetail/VehicleDetailHelpers.swift` (priorityColor, scoreDescription, computed properties)

Computed property'ler (mostCriticalReminder, guideInsights, upcomingTasks) için ortak bir erişim noktası: `VehicleDetailState` struct veya `extension Vehicle` ile model üzerine taşı. Veya paylaşılan `@Query` sonuçlarını bir struct'ta topla, subview'lara parametre olarak geçir.

**Acceptance criteria:**

- Ana `VehicleDetailView.swift` <500 satır.
- Her yeni dosya <400 satır.
- Tüm preview'lar (varsa) bozulmaz.
- Davranış birebir aynı.
- Build + test geçer.

## 2.2 HistoryView filter chips → native segmented

**Dosya:** `Features/Records/HistoryView.swift`

**Mevcut durum:** `filterRail` custom horizontal scroll; `dateFilterRail` benzer ama farklı görsel.

**Yapılacak:**

- `filterRail` yerine:

```swift
Picker("Filtre", selection: $selectedFilter) {
    ForEach(HistoryFilter.allCases, id: \.self) { filter in
        Text(filter.rawValue).tag(filter)
    }
}
.pickerStyle(.segmented)
.padding(.horizontal, AppSpacing.screenMarginH)
```

iOS 17'de segmented otomatik olarak daralır, sığmazsa `.menu`'ya fallback yapar. 5 madde çoğu ekrana sığar.

- `dateFilterRail` için `Menu` kullan:

```swift
Menu {
    Picker("Tarih", selection: $selectedDateRange) {
        ForEach(DateRange.allCases, id: \.self) { range in
            Text(range.rawValue).tag(range)
        }
    }
} label: {
    HStack(spacing: AppSpacing.xs) {
        Image(systemName: "calendar")
        Text(selectedDateRange.rawValue)
        Image(systemName: "chevron.down").font(.caption)
    }
    .font(AppTypography.secondary)
    .foregroundColor(AppColors.accentPrimary)
    .padding(.horizontal, AppSpacing.md)
    .padding(.vertical, AppSpacing.xs)
    .background(Capsule().fill(AppColors.accentPrimary.opacity(0.08)))
}
```

**Acceptance criteria:**

- Filtre seçimi Picker.segmented ile.
- Tarih seçimi Menu.
- Davranış aynı.
- Görsel design system'le uyumlu (accent rengi, AppSpacing token'ları).

## 2.3 Hero image yüksekliği — oransal

**Dosyalar:**

- `Features/Garage/GarageView.swift` (`heroImageArea`, 190pt sabit)
- `Features/VehicleDetail/VehicleDetailView.swift` (`detailHeroPhotoArea`)
- `DesignSystem/Components/VehicleHeroHeader.swift` (`photoArea`, 180pt sabit)

**Yapılacak:**

`.frame(height: 190)` veya `.frame(height: 180)` → `.aspectRatio(16/9, contentMode: .fill)` veya `.containerRelativeFrame(.horizontal) { width, _ in width * 0.55 }`.

`photoArea` içindeki overlay text (Araç Dosyası pill, plaka, vb.) yeniden hizalanmalı.

**Acceptance criteria:**

- Farklı ekran genişliklerinde oran sabit.
- Placeholder gradient ve text overlay hizalı kalır.
- Çok küçük ekranlarda (iPhone SE) taşma olmaz.

## 2.4 DocumentsView temizliği

**Dosya:** `Features/Documents/DocumentsView.swift` (1KB)

**Yapılacak:**

- Önce referansları bul: `grep -r "DocumentsView" /Users/fatihdisci/apps/arvia`.
- Sadece kendi içinde tanımlı, başka yerden çağrılmıyorsa: dosyayı sil.
- Çağrı varsa: caller'ı belirle. Eğer ölü UI ise (kullanıcının erişemediği) caller'ı da kaldır.

**Acceptance criteria:**

- Build warning yok.
- Production davranışı değişmez.

## 2.5 ReportsView para formatı

**Dosya:** `Features/Reports/ReportsView.swift`

**Yapılacak:**

`yearlyTotal`, `monthlyData`, `categoryData`, `topExpenses` UI'da gösterilen her sayısal değer için formatted versiyon ekle:

```swift
var yearlyTotalFormatted: String {
    yearlyTotal.formatted(.currency(code: "TRY").locale(Locale(identifier: "tr_TR")))
}
```

View içinde raw `\(yearlyTotal)` kalan yerleri formatted versiyonla değiştir. Computation (`.reduce(0) + ...`) kalsın; sadece display değişsin.

**Acceptance criteria:**

- Para birimleri "₺200.000,00" formatında görünür.
- Computation aynı (UI testlerinde veya manuel hesaplamayla doğrula).

---

# Testing & validation

Tüm BUCKET 1 + 2 bittikten sonra:

1. **Build:** `xcodebuild -project VehicleDossierApp.xcodeproj -scheme VehicleDossierApp -destination 'platform=iOS Simulator,name=iPhone 15' build` (veya projedeki gerçek scheme adı). `BUILD SUCCEEDED` al.
2. **Testler:** `xcodebuild test` veya Xcode → Test. 89 mevcut test geçsin, hiçbirini kırma.
3. **Lint / Warnings:** Xcode build sonrası warning sayısı artmamalı.
4. **Manuel smoke (simulator):**
   - Fresh install → onboarding flow → "İlk aracımı ekle" → form açılır.
   - Onboarding skip → aynı form.
   - Multi-vehicle garage → sağa/sola kaydır.
   - Garage boş → VoiceOver ile gez.
   - Yeni reminder ekle, custom + araçsız bırak → 2 hata gör.
   - Reminder formuna "192.000" yaz → 192000 kaydedilir.
   - Paywall `PaywallView(feature: .documentLimit)` → farklı başlık gör.
   - History filter → segmented control görünür, çalışır.
   - Reports → ₺ formatında sayılar.
5. **Accessibility Inspector:** Xcode → Developer Tools → Accessibility Inspector. EmptyStateView, EmptyStateView in History, Garage hero card'ı kontrol et. Label/traits mantıklı.

---

# Deliverable (agent'ın çıktısı)

İş bittiğinde rapor ver:

- Değişen dosyaların listesi, her dosya için 1 satır açıklama.
- BUCKET 1'den hangileri tamam (checkbox ✅), BUCKET 2'den hangileri tamam.
- Build ve test sonucu (tek satır her biri).
- Spec'ten sapma varsa gerekçesi.
- Yeni ortaya çıkan TODO varsa listele.
- Kalan manuel iş varsa (App Store Connect input, Supabase SQL, vs.) açıkça yaz.

---

# File map (hızlı referans)

```
App/
  VehicleDossierApp.swift       (1.8 — onboarding flow refactor)
  AppRouter.swift
  AppEnvironment.swift
DesignSystem/
  AppColors.swift               (token — DEĞİŞTİRME)
  AppSpacing.swift              (token — DEĞİŞTİRME)
  AppRadius.swift               (token — DEĞİŞTİRME)
  AppTypography.swift           (token — DEĞİŞTİRME)
  AppShadows.swift              (token — DEĞİŞTİRME)
  ButtonStyles.swift            (token — DEĞİŞTİRME)
  Components/
    EmptyStateView.swift        (1.6 — accessibility)
    ErrorStateView.swift        (1.6)
    VehicleHeroHeader.swift     (2.3 — oransal image)
    ... (diğer componentler — değiştirme)
Models/
  Vehicle.swift
  Reminder.swift                (1.7 — static helper'lar)
  ... (diğer modeller — değiştirme)
Features/
  Garage/
    GarageView.swift            (1.5 — multi-vehicle swipe, 2.3 — hero image)
    VehicleFormView.swift       (1.4 — decimalPad)
  VehicleDetail/
    VehicleDetailView.swift     (2.1 — refactor, 2.3 — hero image)
  Reminders/
    ReminderFormView.swift      (1.3 — validasyon sırası, 1.4 — decimalPad)
    TodosView.swift
    ...
  Paywall/
    PaywallView.swift           (1.1 — context expansion, 1.2 — badge metadata)
  Records/
    HistoryView.swift           (1.7 — predicate helper, 2.2 — segmented)
  Reports/
    ReportsView.swift           (2.5 — para formatı)
  Onboarding/
    OnboardingView.swift        (1.8 — dismiss fix)
  Documents/
    DocumentsView.swift         (2.4 — temizlik)
  Settings/
    SettingsView.swift
  Community/
    ...
```

---

# Son notlar

- Token'lara dokunma: agent "şu radius daha iyi olur" diye bir şey önermesin. Anayasa kuralları.
- Yeni component ekliyorsan `DesignSystem/Components/` altına; feature-local helper'ı feature içinde tut.
- Preview'lar bozulursa düzelt (Xcode preview crash bazen preview-only state'lerden olur; prod'a sızmaz ama kırık bırakma).
- Türkçe metni koru; yeni Türkçe metin ekleyeceksen kısa ve anayasadaki tona uygun olsun.
- Bir fix diğerine bağlanırsa (örn. 1.5 + 2.3 aynı view'da) birlikte yap, ayrı PR'lara bölmeye gerek yok; ama 1.x'te yarım kalmış 2.x'i de yapma.

Kolay gelsin.
