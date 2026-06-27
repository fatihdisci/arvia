# Garajım — Son 4 Commit Raporu

**Tarih:** 27 Haziran 2026
**Branch:** main
**Toplam commit:** 4 (5c6de0e → d4492a5)

---

## Genel Bakış

Bu 4 commit, Garajım uygulamasının Design Polish Phase 1–2, motosiklet desteği ve bilgi mimarisi dönüşümünü kapsar. Toplamda **43 dosya** değişti, **12 yeni dosya** eklendi.

| Commit | Konu | Değişen Dosya | Tarih |
|--------|------|---------------|-------|
| `5c6de0e` | Hesap silme düzeltmesi | 3 | 15:36 |
| `9792d0f` | Design Polish Phase 1-2 + Bug fix + App Store hazırlık | 18 | 16:20 |
| `d24bd3f` | Motosiklet desteği | 10 | 16:45 |
| `d4492a5` | Bilgi mimarisi / UX dönüşümü | 7 | 16:57 |

---

## Commit Detayları

### 1. `5c6de0e` — fix: hesap silme — display_name düzeltildi, DocumentStorageService.deleteAllFiles eklendi

**Amaç:** Hesap silme akışındaki eksiklerin giderilmesi.

**Değişen dosyalar (3):**

| Dosya | Değişiklik |
|-------|-----------|
| `Features/Community/Services/CommunityProfileService.swift` | `anonymizeProfile()`: `display_name` `null` → `"Silinmiş Kullanıcı"` |
| `Features/Settings/SettingsView.swift` | `deleteAccountAndData()`: belge temizliği `DocumentStorageService.deleteAllFiles()` üzerinden |
| `Services/DocumentStorageService.swift` | `deleteAllFiles()` metodu eklendi — tüm belge dizinini temizleyip yeniden oluşturur |

**Hesap silme akışı (doğrulanan):**
- SwiftData 8 model temizleniyor (Vehicle, Reminder, Expense, ServiceRecord, PartChange, VehicleDocument, InspectionReport, SaleFile)
- Fiziksel belge dosyaları temizleniyor
- Bildirimler iptal ediliyor
- Topluluk profili anonimleştiriliyor (hard delete değil — moderation bütünlüğü korunuyor)
- Supabase oturumu kapatılıyor
- Pro state sıfırlanıyor
- Destructive confirmation dialog + Türkçe hata mesajı

---

### 2. `9792d0f` — fix: belge başlık senkronizasyonu, save hata yönetimi, QuickAction navigasyon bağlantıları, PrivacyInfo UGC güncellemesi, Supabase final deploy SQL, Reminder 30 gün özeti

**Amaç:** Design Polish Phase 1-2, belge bug düzeltmeleri, App Store hazırlık.

**Değişen dosyalar (18):**

| Kategori | Dosya | Değişiklik |
|----------|-------|-----------|
| **Bug fix** | `Features/Documents/DocumentFormView.swift` | Başlık auto-sync (`hasUserEditedTitle`), save `do/catch`, preselectedVehicleId, başarı haptik |
| **Bug fix** | `Features/VehicleDetail/VehicleDetailView.swift` | `DocumentFormView(preselectedVehicleId:)`, opsiyonel interpolasyon fix |
| **UX** | `Features/Garage/GarageView.swift` | QuickActionRail 5 buton bağlantısı, paywall gate'leri |
| **UX** | `Features/Reminders/ReminderListView.swift` | 30 gün özet modülü, boş durum kopyası, tamamlama haptik |
| **UX** | `Features/Reminders/ReminderFormView.swift` | `init(preselectedVehicleId:)` |
| **UX** | `Features/Expenses/ExpenseFormView.swift` | `preselectedVehicleId` init parametresi |
| **UX** | `Features/ServiceRecords/ServiceRecordFormView.swift` | `preselectedVehicleId` init parametresi |
| **UX** | `Features/Reports/ReportsView.swift` | PremiumMetricHero + OwnershipInsightCards |
| **DesignSystem** | `QuickActionTile.swift` | **Yeni** — QuickActionTile + QuickActionRail |
| **DesignSystem** | `DossierCompletenessCard.swift` | **Yeni** — Dairesel ilerleme kartı |
| **DesignSystem** | `OwnershipInsightCard.swift` | **Yeni** — Sahiplik içgörü kartı |
| **DesignSystem** | `BrandIntroView.swift` | **Yeni** — 1.8sn premium reveal |
| **App Store** | `Resources/PrivacyInfo.xcprivacy` | UGC, e-posta, isim, fotoğraf, satın alma veri türleri |
| **Supabase** | `docs/SUPABASE_FINAL_DEPLOY.sql` | **Yeni** — Birleşik şema + RLS + trigger + index |
| **Other** | `Services/CommunityAuthService.swift` | `guard let client` → `guard client != nil` fix |
| **Other** | `Features/Settings/SettingsView.swift` | `saleFiles` export'a eklendi |
| **Project** | `VehicleDossierApp.xcodeproj/project.pbxproj` | 4 yeni DesignSystem komponenti |
| **App** | `App/VehicleDossierApp.swift` | BrandIntroView wrapper |

---

### 3. `d24bd3f` — feat: motosiklet desteği — VehicleType, MotorcycleType, özel şablonlar, form ve skor uyarlamaları

**Amaç:** Uygulamayı otomobil + motosiklet destekleyecek şekilde genişletmek.

**Değişen dosyalar (10):**

| Kategori | Dosya | Değişiklik |
|----------|-------|-----------|
| **Model** | `Models/AppBrand.swift` | **Yeni** — Merkezi marka sabitleri |
| **Model** | `Models/Enums.swift` | `VehicleType` (car/motorcycle), `MotorcycleType` (8 tip), motosiklet özel ReminderType (8), ExpenseCategory (2), DocumentType (3) |
| **Model** | `Models/Vehicle.swift` | `vehicleTypeRaw`, `motorcycleTypeRaw`, `engineCC` — migration güvenli (varsayılan: car) |
| **Form** | `Features/Garage/VehicleFormView.swift` | Araç türü seçici, motosiklet tipi + motor hacmi alanları |
| **Form** | `Features/VehicleDetail/VehicleEditView.swift` | vehicleType/motorcycleType/engineCC state + init |
| **Hero** | `DesignSystem/Components/VehicleHeroHeader.swift` | `car.fill` / `bicycle` ikonu |
| **Hero** | `Features/Garage/GarageView.swift` | Hero icon + skor motosiklet uyumlu |
| **Skor** | `Features/VehicleDetail/VehicleDetailView.swift` | `computeFileScore()` motosiklet engineCC bonus |
| **Skor** | `App/VehicleDossierApp.swift` | Retention skor motosiklet uyumlu |
| **Test** | `Tests/ModelTests.swift` | 10 yeni motosiklet testi |

**Yeni enum değerleri:**

| Enum | Eklenen | Sayı |
|------|---------|------|
| `VehicleType` | car, motorcycle | 2 |
| `MotorcycleType` | scooter, naked, touring, enduro, cruiser, sport, commuter, other | 8 |
| `ReminderType` | chainMaintenance, chainSprocketSet, sparkPlug, airFilter, clutchCable, suspensionCheck, seasonStartCheck, winterPrep | +8 (22 toplam) |
| `ExpenseCategory` | chainSprocket, equipment | +2 (21 toplam) |
| `DocumentType` | equipmentInvoice, helmetGearWarranty, accessoryMounting | +3 |

---

### 4. `d4492a5` — feat: bilgi mimarisi dönüşümü — tab isimleri, Yapılacaklar detay, Geçmiş filtreler

**Amaç:** Kullanıcı zihinsel modelini netleştirmek: "İşler/Kayıtlar" ayrımı yerine "Yapılacaklar/Geçmiş".

**Değişen dosyalar (7):**

| Kategori | Dosya | Değişiklik |
|----------|-------|-----------|
| **Tab bar** | `App/AppRouter.swift` | Tab enum: `.reminders→.todos`, `.records→.history`. İkon: `checklist`, `clock.arrow.circlepath` |
| **Yeni** | `Features/Reminders/TodosView.swift` | Yapılacaklar sarmalayıcısı, bildirim izni |
| **Yeni** | `Features/Reminders/ReminderDetailView.swift` | Tap-detay: durum başlığı, detay kartı, tamamla/düzenle/sil, tamamlama→Geçmiş akışı |
| **Güncelleme** | `Features/Reminders/ReminderListView.swift` | Satırlar `NavigationLink` ile tıklanabilir, boş durum kopyası |
| **Yeni** | `Features/Records/HistoryView.swift` | Geçmiş: 5 filtre (Tümü/Masraflar/Bakımlar/Belgeler/Ekspertiz), filtre bazlı boş durumlar, timeline |
| **Test** | `Tests/ModelTests.swift` | ReminderType count (23→22) |
| **Project** | `VehicleDossierApp.xcodeproj/project.pbxproj` | 3 yeni dosya |

**Tab yapısı:**

| # | Tab | İkon | İçerik |
|---|-----|------|--------|
| 1 | Garaj | `car` | Araç kartı, hızlı işlemler, dosya tamlığı |
| 2 | Yapılacaklar | `checklist` | Gelecek işler (muayene, sigorta, bakım…) |
| 3 | Geçmiş | `clock.arrow.circlepath` | Yapılmış işlemler (masraf, bakım, belge, ekspertiz) |
| 4 | Raporlar | `chart.bar` | Maliyet analizi, sahiplik içgörüleri |
| 5 | Topluluk | `person.3` | Kontrollü forum |

---

## 12 Yeni Dosya

| # | Dosya | Commit | Açıklama |
|---|-------|--------|----------|
| 1 | `Models/AppBrand.swift` | `d24bd3f` | Merkezi marka sabitleri |
| 2 | `DesignSystem/Components/QuickActionTile.swift` | `9792d0f` | Hızlı işlem butonu + rail |
| 3 | `DesignSystem/Components/DossierCompletenessCard.swift` | `9792d0f` | Dosya tamlığı kartı |
| 4 | `DesignSystem/Components/OwnershipInsightCard.swift` | `9792d0f` | Sahiplik içgörü kartı |
| 5 | `DesignSystem/Components/BrandIntroView.swift` | `9792d0f` | App açılış reveal |
| 6 | `docs/SUPABASE_FINAL_DEPLOY.sql` | `9792d0f` | Birleşik Supabase deployment SQL |
| 7 | `Features/Reminders/TodosView.swift` | `d4492a5` | Yapılacaklar tab |
| 8 | `Features/Reminders/ReminderDetailView.swift` | `d4492a5` | Yapılacak detay ekranı |
| 9 | `Features/Records/HistoryView.swift` | `d4492a5` | Geçmiş tab (filtreli) |

---

## Build / Test Özeti

| Commit | Debug Build | Test |
|--------|-------------|------|
| `5c6de0e` | ✅ | ✅ (79 test) |
| `9792d0f` | ✅ | ✅ (79 test) |
| `d24bd3f` | ✅ | ✅ (79 test — yeni testler sonraki committe aktif) |
| `d4492a5` | ✅ | ✅ (89 test) |

---

## Ürün Durumu

### Tamamlanan

- [x] DesignSystem token tabanlı premium UI (QuickActionRail, DossierCompletenessCard, OwnershipInsightCard)
- [x] BrandIntroView (1.8sn premium reveal)
- [x] Belge başlık auto-sync + save hata yönetimi
- [x] QuickActionRail 5 buton navigasyon bağlantısı
- [x] PrivacyInfo.xcprivacy UGC/App Store uyumlu
- [x] Supabase final deploy SQL (şema + RLS + trigger)
- [x] Reminder 30 gün özet modülü
- [x] Motosiklet desteği (VehicleType, MotorcycleType, özel enum'lar, form, skor)
- [x] Tab isimleri: Yapılacaklar / Geçmiş
- [x] ReminderDetailView (tap-detay + tamamlama→Geçmiş akışı)
- [x] HistoryView (5 filtreli birleşik geçmiş)
- [x] Hesap silme akışı (SwiftData + belge + Supabase anonimleştirme)

## Kalan Riskler, Eksikler ve Öneriler

### Kritik (TestFlight öncesi mutlaka yap)

| # | İş | Açıklama | Efor |
|---|-----|----------|------|
| 1 | **ReminderDetailView edit** | Düzenleme sheet'i `ReminderFormView()` ile açılıyor ama mevcut veriyi taşımıyor. `existingReminder` parametresi eklenmeli. | 30dk |
| 2 | **HistoryView → delete** | Masraf/bakım/belge satırlarında silme aksiyonu yok. Swipe-to-delete eklenmeli. | 30dk |
| 3 | **HistoryView → detail tap** | Masraf/bakım satırlarına tıklanınca düzenleme/detay açılmalı. | 45dk |
| 4 | **Supabase SQL çalıştırma** | `SUPABASE_FINAL_DEPLOY.sql` manuel çalıştırılmalı (commit otomatik değiştirmez). | 5dk |
| 5 | **VehicleDossierApp/ temizliği** | Eski kopyalar `VehicleDossierApp/` altında. Pbxproj'da referans yok, karışıklık yaratıyor. | 15dk |

### Yüksek (ilk TestFlight'ta olmalı)

| # | İş | Açıklama | Efor |
|---|-----|----------|------|
| 6 | **Onboarding akışı** | 3-4 ekranlı first-run. "Aracının dijital dosyası" mantığını öğretmeli. BrandIntroView sonrasına eklenebilir. | 2-3sa |
| 7 | **Dosyanı tamamla checklist** | İlk araç sonrası Garaj'da interaktif checklist kartı. Item'lar ilgili formlara yönlendirmeli. | 1-2sa |
| 8 | **ReminderFormView filtre** | `templates(for:)` hazır ama form kullanmıyor. Motosiklet→zincir/buji, otomobil→triger/HGS. | 30dk |
| 9 | **ExpenseFormView filtre** | `categories(for:)` hazır ama form kullanmıyor. | 30dk |
| 10 | **VehicleEditView vehicleType UI** | State var ama Picker yok. Kullanıcı araç türünü düzenleyemiyor. | 30dk |

### Orta (V1.1)

| # | İş | Açıklama | Efor |
|---|-----|----------|------|
| 11 | **Contextual tips** | Bağlama göre inline info kartları. UserDefaults "görüldü" takibi. Kapatılabilir. | 2-3sa |
| 12 | **AppBrand geçişi** | Tüm hardcoded "Garajım" → `AppBrand.appName`. Kademeli. | 1sa |
| 13 | **Motosiklet icon** | `bicycle` ideal değil. Custom asset veya alternatif SF Symbol. | 1sa |
| 14 | **Form success feedback** | Masraf/bakım kaydında haptik + animasyon. Şu an sadece belge formunda var. | 45dk |
| 15 | **Premium row tasarımı** | Geçmiş/Expense listelerinde varsayılan List yerine özel row. | 1-2sa |

### Düşük (V1.2+)

| # | İş |
|---|-----|
| 16 | RevenueCat webhook → Supabase Edge Function → `profiles.is_pro` sync |
| 17 | APNs push notification (topluluk beğeni/yorum) |
| 18 | PrivacyInfo Supabase domain listesi |
| 19 | Araç Yaşam Çizgisi event genişletme animasyonu |
| 20 | CSV/PDF export |
| 21 | Belgeler sekmesi geri dönüşü (feedback'e göre) |
| 22 | GarageView ikincil araç kompakt hero card |

### Önerilen Yol Haritası

- **Faz A — TestFlight Blocker (1-2 gün):** #1-5
- **Faz B — TestFlight V1 (3-5 gün):** #6-10
- **Faz C — V1.1 (1-2 hafta):** #11-15
- **Faz D — V1.2+ (1 ay+):** #16-22

---

## Manuel Yapılması Gerekenler

### Supabase (manuel — commit otomatik yapmaz)
1. SQL Editor → `docs/SUPABASE_FINAL_DEPLOY.sql` **tamamını** yapıştır → Run
2. Authentication → Apple provider: Service ID, callback URL, p8 key doğrula
3. Admin oluştur: `UPDATE profiles SET role='admin', is_verified=true, is_pro=true WHERE id='<UUID>';`

### Xcode (manuel)
4. Signing & Capabilities → Sign in with Apple aktif mi?
5. Build Settings → `INFOPLIST_KEY_SUPABASE_URL/ANON_KEY` değerlerini kontrol et
6. `Config.xcconfig` production değerleri (gitignored — commitlenmez!)

### App Store Connect (manuel)
7. App Privacy labels → PrivacyInfo.xcprivacy ile tutarlı mı?
8. TestFlight Internal Testing grubu kur
9. App Review: UGC moderasyon, hesap silme, paywall restore, gizlilik linkleri hazır

---

## Genişletilmiş Manuel Test Checklist

### Araç
- [ ] Otomobil ekle (tüm alanlar)
- [ ] Motosiklet ekle (tip + motor hacmi)
- [ ] Araç düzenle / arşivle / sil

### Yapılacaklar
- [ ] Tab: "Yapılacaklar" + `checklist` ikonu
- [ ] Boş durum: "Yaklaşan iş yok" + "Yapılacak Ekle"
- [ ] Satıra TAP → ReminderDetailView (durum, detay, araç, aksiyonlar)
- [ ] Düzenle / Sil (confirmation) / Tamamlandı İşaretle
- [ ] Bakım işi tamamlanınca "Bakım Kaydı Oluştur" seçeneği
- [ ] Swipe actions (Tamamla / Sil)

### Geçmiş
- [ ] Tab: "Geçmiş" + `clock.arrow.circlepath` ikonu
- [ ] Filtreler: Tümü / Masraflar / Bakımlar / Belgeler / Ekspertiz
- [ ] Her filtre boş durumda doğru mesaj + CTA
- [ ] "+" menüsü → 4 kayıt türü ekleme
- [ ] Belge → tıkla → QuickLook

### Garaj
- [ ] Hero kart (ikon vehicleType'a göre)
- [ ] QuickActionRail: Masraf / Bakım / Belge / Hatırlatıcı / Satış
- [ ] Dosya Tamlığı kartı
- [ ] Son İşlemler / İkincil araçlar

### Raporlar / Satış / Paywall / Topluluk
- [ ] Hero metrik + OwnershipInsightCards
- [ ] Satış dosyası PDF + paylaşım
- [ ] Paywall gate'ler (araç/belge/satış) + restore
- [ ] Topluluk: giriş, gönderi, yorum, beğeni, şikayet, moderasyon

### Erişilebilirlik
- [ ] Dark mode — tüm yeni ekranlar okunaklı
- [ ] Dynamic Type — büyük metin boyutları
- [ ] VoiceOver — icon-only butonlarda label
- [ ] Reduce Motion — animasyonlar atlanıyor
- [ ] Tap target min 44pt

### Hesap Silme
- [ ] Ayarlar → Hesabı ve Verileri Sil → onay
- [ ] SwiftData + belge dosyaları + bildirimler temizleniyor
- [ ] Topluluk profili anonimleşiyor (deleted_user_XXXX)
- [ ] Supabase sign out + Pro state sıfırlanıyor
