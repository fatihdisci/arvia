# CLAUDE.md — Arvia (Ruhsatim)

Araç dijital dosyası uygulaması. iOS only, SwiftUI, SwiftData, local-first.

**Önce şu dosyaları oku:** `ROADMAP.md` (stratejik kararlar + yol haritası), `01_DESIGN.md` (tasarım anayasası), `02_PRODUCT_SCOPE.md` (feature haritası), `03_SWIFTUI_ARCHITECTURE.md` (teknik mimari).

## Mimari

```
ObservableObject + SwiftData + Feature-based modular
- @StateObject + @EnvironmentObject ViewModel'ler
- Singleton servisler (.shared)
- SwiftData container: [Vehicle, Reminder, Expense, ServiceRecord, PartChange, VehicleDocument, InspectionReport, SaleFile]
- CloudKit sync: altyapı hazır, feature flag kapalı
- Supabase: Community auth + sync (opsiyonel)
```

**Dizin yapısı:**
| Dizin | İçerik |
|--------|--------|
| `App/` | Entry point, AppEnvironment, AppRouter |
| `DesignSystem/` | DesignTokens, AppColors, AppTypography, AppSpacing, AppRadius, AppShadows, ButtonStyles, Components/ |
| `Models/` | Vehicle, Reminder, Expense, ServiceRecord, PartChange, VehicleDocument, InspectionReport, SaleFile, VehicleInsight, AppBrand, Enums |
| `Services/` | 15 servis (Notification, PDFExport, DocumentStorage, ReminderRepeat, Paywall, CommunityAuth, VehicleInsight, CarCatalog, DataExport, DemoDataSeeder, Supabase, RetentionNotification, VehiclePhotoStorage, InsightSnooze) |
| `Features/` | 14 modül (Garage, VehicleDetail, Reminders, Expenses, Documents, SaleFile, Reports, Settings, Onboarding, Paywall, Community, Records, InspectionReport, ServiceRecords) |
| `Tests/` | CommunityTests, DataExportServiceTests, InsightSnoozeStoreTests, ModelTests (151 test) |

## Tasarım Prensipleri (HER İŞTE UY)

1. **Token-only:** `AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, `AppShadows` — ham hex/renk/boşluk yok
2. **AI-slop yasak:** mavi-mor gradient, glassmorphism, opacity çorbası, generic SaaS kart grid
3. **Apple-native:** SF Symbols, native List/Form, system renkler
4. **Anlamlı her element:** dekoratif öğe yok
5. **Boş/hata state zorunlu:** her yeni view'da EmptyStateView + ErrorStateView
6. **Accessibility:** Dynamic Type, VoiceOver label, 44pt minimum tap target
7. **Dark mode gerçek:** sadece invert değil, elle tasarlanmış
8. **Bilgi > eylem:** CTA sadece kritik/yasal durumlarda. Bilgi/Uyarı/Hatırlatma kartlarında dismiss yeterli.

## Tema

- **Her zaman dark:** `.preferredColorScheme(.dark)`
- **Renk paleti:** Altın vurgu (`#E6C479`), koyu surface (`#0F131F`), secondary text (`#8B95A8`)
- **Locale:** `tr_TR` sabit
- **Design token'ları:** `AppColors.swift`, `AppTypography.swift`, `AppSpacing.swift`, `AppRadius.swift`, `AppShadows.swift`, `ButtonStyles.swift`

## Önemli Desenler

### State Yönetimi (ObservableObject — eski pattern)
- `@StateObject` ile ViewModel sahipliği
- `@EnvironmentObject` ile cross-cutting dependency
- `@Published` ile property değişiklik bildirimi
- NOT: `@Observable` pattern'ine geçiş planlanabilir

### Servis Mimarisi
- Singleton: `static let shared = XService()`
- Environment ile inject: `.environmentObject(paywallService)`
- `PaywallService`, `CommunityAuthService`: `@StateObject` ile App level

### Veri
- SwiftData `ModelContainer` ile
- CloudKit opsiyonel: `AppEnvironment.isCloudKitSyncEnabled`
- Supabase: `SupabaseClientProvider` üzerinden (community/auth)
- Local-first: tüm temel özellikler çevrimdışı çalışır

### Testler
- 151 test, 4 test dosyası
- `DemoDataSeeder` ile DEBUG seed data
- 5 test senaryosu (empty, single, overdue, busy, quietGood)

## Önemli Kararlar (ROADMAP.md'den)

- **Free limit:** 1 araç bedava, 2+ = Pro (`PaywallService.FreeLimits.maxVehicles = 1`)
- **Family Sharing:** Kapalı (Türkiye'de yaygın değil)
- **Lifetime ürünü:** Korunuyor (şimdilik)
- **Açık mod border:** Border + Subtle Fill (`#FAFAFA` surface, `#AEAEB2` border)
- **Dosya Skoru:** "Dosya Tamlığı" değil "Dosya Skoru", icon `chart.bar.fill`
- **Arvia Rehber (aktif faz):** 13 CTA-zorunlu kart → 5 içerik tipi (CTA/Bilgi/Uyarı/Hatırlatma/Soru)
- **Usta tarafı:** Ayrı app target "Arvia Servis" (Faz 4.2, ~23-31 gün)
- **CloudKit:** Altyapı hazır, `isCloudKitSyncEnabled = false`, karar kullanıcı verisiyle

## Build

- Xcode projesi: `VehicleDossierApp.xcodeproj`
- Scheme: `Ruhsatim`
- Simulator: iPhone 17 Pro
- `xcodebuild -project VehicleDossierApp.xcodeproj -scheme Ruhsatim -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- Test: `xcodebuild -project VehicleDossierApp.xcodeproj -scheme Ruhsatim -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

## Git

- Conventional commits: `feat:`, `fix:`, `chore:`, `build:`, `refactor:`
- Branch: `main`
- Remote: GitHub (`fatihdisci/ruhsatim`)
