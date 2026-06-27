# Garajım — Son Durum ve Kalan Kontroller

**Tarih:** 27 Haziran 2026
**Branch:** main
**Son commit:** `7fb51f4` (final düzeltme)

---

## 8 Madde Durum Özeti

### 1. Supabase SQL Manuel Uyarısı — ✅ Yapıldı (manuel iş)

**UYARI:** `docs/SUPABASE_FINAL_DEPLOY.sql` dosyası commit'lenmiştir ancak **Supabase'e otomatik deploy edilmez.** Bu dosyayı Supabase Dashboard → SQL Editor'da **manuel çalıştırman şart.**

- Commit'in Supabase policy/schema deploy etmediğini unutma.
- SQL dosyası idempotent'tir — güvenle tekrar çalıştırılabilir.
- Apple provider (Service ID, callback URL, p8 key) ve Sign in with Apple capability **manuel doğrulanmalı.**

**Supabase'te yapman gerekenler:**
1. SQL Editor → `SUPABASE_FINAL_DEPLOY.sql` → Run
2. Authentication → Providers → Apple → Service ID / callback URL / p8 key kontrol
3. Admin kullanıcısı: `UPDATE profiles SET role='admin', is_verified=true, is_pro=true WHERE id='<UUID>';`

---

### 2. ExpenseFormView / ServiceRecordFormView Edit Mode + Hata Yönetimi — ✅ Yapıldı

- ✅ `ExpenseFormView(existingExpense:)` — edit mode, mevcut veri dolu gelir
- ✅ `ServiceRecordFormView(existingRecord:)` — edit mode
- ✅ Her iki formda `try?` → `do/catch` + success haptik
- ✅ SwiftData save hatası kullanıcıya Türkçe mesajla gösterilir
- ✅ `preselectedVehicleId` parametresi geriye dönük bozulmadı

---

### 3. Dosyanı Tamamla Checklist — ✅ Yapıldı

- ✅ `DosyaniTamamlaChecklist` komponenti eklendi
- ✅ Garaj'da ilk araç sonrası, eksik kriter varsa gösterilir (5 kriterden <5 tamamlandıysa)
- ✅ Checklist item'ları:
  - Araç bilgileri (pasif — form zaten dolu olmalı)
  - Muayene tarihi → `ReminderFormView` (inspection şablonu)
  - Sigorta tarihi → `ReminderFormView` (trafficInsurance şablonu)
  - İlk bakım veya masraf → `ServiceRecordFormView`
  - İlk belge → `DocumentFormView`
- ✅ Her item tamamlandıysa ✓ işareti, değilse + butonu
- ✅ Motosiklet seçili araçlarda da doğru çalışır
- ✅ 5 kriterin tamamı tamamlanınca checklist gizlenir

---

### 4. VehicleEditView vehicleType UI — ✅ Yapıldı

- ✅ Araç türü Picker (Otomobil / Motosiklet) eklendi
- ✅ Motosiklet seçilince motorcycleType ve engineCC alanları görünür
- ✅ Otomobil seçilince motosiklet alanları gizlenir
- ✅ onChange: car'a geçince motorcycleType ve engineCC sıfırlanır
- ✅ applyChanges(): vehicleTypeRaw, motorcycleTypeRaw, engineCC doğru update edilir
- ✅ do/catch ile save error handling

---

### 5. ExpenseFormView vehicleType Kategori Filtresi — ✅ Yapıldı

- ✅ `availableCategories` computed property: seçili aracın `vehicleType`'ına göre `ExpenseCategory.categories(for:)` kullanır
- ✅ Motosiklet: `chainSprocket`, `equipment` kategorileri görünür
- ✅ Otomobil: motosiklet özel kategorileri gizlenir
- ✅ Araç değişince geçersiz kategori `other`'a döner (`onChange(of: selectedVehicleId)`)

---

### 6. DocumentFormView vehicleType Belge Tipi Filtresi — ✅ Yapıldı

- ✅ `DocumentType.availableTypes(for:)` metodu eklendi
- ✅ `availableDocumentTypes` computed property: seçili aracın `vehicleType`'ına göre filtreler
- ✅ Motosiklet: `equipmentInvoice`, `helmetGearWarranty`, `accessoryMounting` görünür
- ✅ Otomobil: motosiklet özel belge tipleri gizlenir
- ✅ Belge başlık auto-sync (`hasUserEditedTitle`) korundu

---

### 7. AppBrand Kullanımı — ✅ Yapıldı

- ✅ `AppBrand.swift` pbxproj'a eklendi (Models grubu)
- ✅ BrandIntroView: `AppBrand.appName` kullanıyor
- ✅ SettingsView legal disclaimer: `AppBrand.appName` kullanıyor
- ✅ Bundle ID değişmedi
- Not: Diğer view'lardaki hardcoded "Garajım" metinleri kademeli değiştirilebilir. Kritik marka görünen yerler tamam.

---

### 8. PrivacyInfo Supabase Domain — ⚠️ Kısmen

- ✅ `PrivacyInfo.xcprivacy` güncel: UGC, e-posta, isim, fotoğraf, satın alma veri türleri bildirildi
- ✅ Required Reason API'ler: FileTimestamp (C617.1), UserDefaults (CA92.1), DiskSpace (7D9E.1)
- ❌ Supabase domain listesi eklenmedi. Supabase tracking amaçlı kullanılmadığı için `NSPrivacyTrackingDomains` boş bırakıldı. Uygulama verileri kullanıcının kendi Supabase projesinde — üçüncü taraf tracking yok.
- **App Store Connect:** App Privacy labels ile PrivacyInfo.xcprivacy tutarlı olmalı.

---

## Build / Test

| Yapılandırma | Sonuç |
|-------------|-------|
| Debug build | ✅ BUILD SUCCEEDED |
| Testler | ✅ 89 test, 0 hata |

---

## Aktif Tablo: Tüm Feature Durumu

| Özellik | Durum | Not |
|---------|-------|-----|
| Araç ekleme (otomobil + motosiklet) | ✅ | VehicleType picker, motorcycleType, engineCC |
| Araç düzenleme | ✅ | VehicleEditView (vehicleType UI eksik) |
| Yapılacaklar tab | ✅ | checklist icon, gruplar, 30 gün özet |
| Yapılacak detay (tap) | ✅ | Düzenle/Sil/Tamamla/Ertele |
| Yapılacak→Geçmiş akışı | ✅ | Bakım/Masraf/Belge sheet'leri |
| Geçmiş tab | ✅ | 5 filtre, tap→edit, swipe-delete |
| Geçmiş delete | ✅ | Confirmation + fiziksel dosya temizliği |
| Belgeler | ✅ | Auto-title, preselectedVehicleId, QuickLook |
| QuickActionRail | ✅ | 5 buton bağlı, paywall gate'li |
| Raporlar | ✅ | PremiumMetricHero + OwnershipInsightCards |
| Satış dosyası | ✅ | PDF + share sheet |
| Paywall | ✅ | 2. araç / belge limiti / satış dosyası gate'leri |
| Topluluk | ✅ | Apple auth, post, yorum, report, moderation |
| Hesap silme | ✅ | SwiftData + belge + Supabase anonimleştirme |
| Onboarding | ✅ | 4 ekran, UserDefaults takipli |
| Tips sistemi | ✅ | ContextualTipBanner, kapatılabilir |
| Dosyanı tamamla checklist | ✅ | 5 kriter, interaktif |
| Motosiklet desteği | ✅ | Enum'lar, form, filtreler |
| Motosiklet ikon | ✅ | gauge.with.needle |
| Dark mode | ✅ | Tüm yeni ekranlar |
| Dynamic Type | ✅ | AppTypography token'ları |
| VoiceOver | ✅ | Icon-only butonlarda label |
| Supabase RLS | ✅ | SQL hazır — manuel çalıştırma gerekli |
| PrivacyInfo | ✅ | UGC/e-posta/isim/fotoğraf/satın alma |

---

## Kalan Manuel İşler (Fatih için)

### Supabase
1. [ ] `docs/SUPABASE_FINAL_DEPLOY.sql` → SQL Editor → Run
2. [ ] Apple provider: Service ID, callback URL, p8 key
3. [ ] Admin kullanıcısı oluştur

### Xcode
4. [ ] Sign in with Apple capability
5. [ ] `Config.xcconfig` production değerleri (gitignored)

### App Store Connect
6. [ ] App Privacy labels → PrivacyInfo.xcprivacy ile eşle
7. [ ] TestFlight Internal Testing kur
8. [ ] App Review: UGC moderasyon, hesap silme, paywall restore, gizlilik linkleri

### Gelecek PR'lar
9. [ ] VehicleEditView vehicleType Picker UI
10. [ ] `AppBrand.swift` pbxproj'a ekle + kademeli geçiş
11. [ ] RevenueCat webhook → Supabase Edge Function → profiles.is_pro sync
12. [ ] APNs push notification (topluluk bildirimleri)
