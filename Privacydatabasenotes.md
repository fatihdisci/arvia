# Veri Saklama Mimarisi Denetimi — Ruhsatım

**Tarih:** 24 Haziran 2026
**Kapsam:** SwiftData, dosya sistemi, ödeme, dış bağımlılık, iCloud, gizlilik

---

## 1. Veri Nerede Tutuluyor?

| Katman | Konum | Motor | Kalıcılık |
|---|---|---|---|
| Yapısal veri (araç, masraf, hatırlatıcı...) | App sandbox | SwiftData → Core Data / SQLite | Kalıcı |
| Belge dosyaları (PDF, fotoğraf) | `Documents/VehicleDocuments/` | `FileManager` | Kalıcı |
| PDF çıktısı (satış dosyası) | `NSTemporaryDirectory()` | `UIGraphicsPDFRenderer` | Geçici |
| Pro durumu (dev mode) | `UserDefaults` | `paywall_dev_is_pro` key | Kalıcı |
| Bildirimler | `UNUserNotificationCenter` | Sistem | Kalıcı |

---

## 2. SwiftData Container

**Konum:** `App/VehicleDossierApp.swift:13-36`

```swift
let schema = Schema([Vehicle, Reminder, Expense, ServiceRecord,
                     PartChange, VehicleDocument, InspectionReport, SaleFile])
let config = ModelConfiguration(isStoredInMemoryOnly: false, allowsSave: true)
modelContainer = try ModelContainer(for: schema, configurations: config)
```

| Özellik | Değer |
|---|---|
| Depolama | Disk (SQLite) |
| `isStoredInMemoryOnly` | `false` |
| CloudKit sync | Kapalı (`isCloudKitSyncEnabled = false`) |
| Supabase | Kapalı (`isSupabaseEnabled = false`) |
| Migration | Otomatik (SwiftData lightweight) |

---

## 3. @Model Sınıfları ve İlişkiler

**8 model, tamamı `@Model`:**

| Model | İlişki | Yöntem |
|---|---|---|
| `Vehicle` | Root | `id: UUID` |
| `Reminder` | → Vehicle | `vehicleId: UUID` (FK) |
| `Expense` | → Vehicle | `vehicleId: UUID` (FK) |
| `ServiceRecord` | → Vehicle | `vehicleId: UUID` (FK) |
| `PartChange` | → ServiceRecord | `serviceRecordId: UUID` (FK) |
| `VehicleDocument` | → Vehicle | `vehicleId: UUID` (FK) |
| `InspectionReport` | → Vehicle | `vehicleId: UUID` (FK) |
| `SaleFile` | → Vehicle | `vehicleId: UUID` (FK) |

> ⚠️ **İlişki tipi: Manuel FK.** `@Relationship` makrosu kullanılmamış. Tüm cascade delete işlemleri `VehicleDetailView.deleteVehicle()` içinde manuel yapılıyor.

---

## 4. Belge Fiziksel Depolama

**`DocumentStorageService`** — `Services/DocumentStorageService.swift`

| İşlem | Metod | Detay |
|---|---|---|
| Kaydet | `saveFile(from:originalFileName:documentId:)` | Kaynaktan `Documents/VehicleDocuments/{UUID}.{ext}` konumuna kopyalar |
| Dosya adı | `documentId.uuidString + ext` | UUID tabanlı, çakışma yok |
| Oku | `fileURL(for:)` | Sandbox içi `file://` URL |
| Sil | `deleteFile(_:)` | `FileManager.removeItem` ile diskten siler |
| Kontrol | `fileExists(_:)` | Varlık kontrolü |
| Toplam alan | `totalStorageUsed` | Byte cinsinden |

**App sandbox içinde:** ✅ Evet
```swift
FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("VehicleDocuments", isDirectory: true)
```

---

## 5. Belge Silme → Fiziksel Temizlik

### Belge bazlı silme ✅
`DocumentListView.deleteDocument()` → `DocumentStorageService.shared.deleteFile()` → `modelContext.delete()`

```swift
// DocumentListView.swift:189-193
private func deleteDocument(_ doc: VehicleDocument) {
    try? DocumentStorageService.shared.deleteFile(doc.localFileName)  // disk
    modelContext.delete(doc)                                           // DB
    try? modelContext.save()
}
```

### Tüm verileri silme ✅
`SettingsView.deleteAllData()` → tüm modeller + `VehicleDocuments/` klasörü silinir

### Araç başına silme ⚠️
`VehicleDetailView.deleteVehicle()` → **SwiftData'dan siler ama fiziksel belge dosyalarını temizlemez.**

```
Araç silinince cascade delete (manuel):
  ├── Reminder       ✅ (vehicleId)
  ├── Expense        ✅ (vehicleId)
  ├── ServiceRecord  ✅ (vehicleId)
  ├── PartChange     ✅ (serviceRecordId)
  ├── VehicleDocument ✅ (vehicleId) — DB'den silinir
  ├── InspectionReport ✅ (vehicleId)
  └── SaleFile       ✅ (vehicleId)

  ❌ Fiziksel belge dosyaları (Documents/VehicleDocuments/) — TEMİZLENMİYOR
```

---

## 6. PDF Export

**`PDFExportService`** — `Services/PDFExportService.swift`

```swift
let outputURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("SatisDosyasi-{uuid}.pdf")
```

| Özellik | Değer |
|---|---|
| Hedef | `NSTemporaryDirectory()` |
| Kalıcılık | Geçici — sistem periyodik temizler |
| Format | A4, `UIGraphicsPDFRenderer` |
| Paylaşım | `ShareLink` ile kullanıcı başlatır |

---

## 7. Ödeme Sistemi

| Soru | Cevap |
|---|---|
| StoreKit mi RevenueCat mi? | **StoreKit 2** (native Apple) |
| RevenueCat SDK | Kodda **yok** |
| RevenueCat referansı | Sadece `reports.md` ve `AppStoreMetadata.md`'de gelecek planı |
| Ürün ID'leri | `com.ruhsatim.pro.monthly`, `.yearly`, `.lifetime` |
| Dev mode | `#if DEBUG` → `UserDefaults` simülasyonu |

```swift
// PaywallService.swift
import StoreKit                    // ← SADECE StoreKit
private let productIDs = ["com.ruhsatim.pro.monthly", ...]
var isDevMode: Bool { #if DEBUG return true #else return false #endif }
```

---

## 8. Dış Bağımlılıklar

### Tam liste: **SIFIR**

| Kategori | Bağımlılık | Durum |
|---|---|---|
| Backend | Supabase | Feature flag: `false`, kod yok |
| Backend | Firebase | Yok |
| Ödeme | RevenueCat SDK | Yok |
| Analytics | Amplitude, Mixpanel, AppsFlyer | Yok |
| Crash | Sentry, Crashlytics | Yok |
| A/B test | Optimizely, LaunchDarkly | Yok |
| SPM paketi | Herhangi | Yok (`Package.swift` yok) |

### Sadece Apple framework'leri kullanılıyor:

`SwiftUI`, `SwiftData`, `StoreKit`, `PDFKit`, `QuickLook`, `PhotosUI`, `Charts`, `UserNotifications`, `VisionKit`, `UniformTypeIdentifiers`, `CoreGraphics`, `UIKit`, `Foundation`

**Uygulama tamamen offline çalışır. Hiçbir ağ isteği yok.**

---

## 9. CloudKit

| Durum | ❌ Kapalı |
|---|---|
| Feature flag | `AppEnvironment.isCloudKitSyncEnabled = false` |
| Container tipi | `ModelConfiguration` (CloudKit değil) |
| Kod referansı | Sadece PaywallService'de `"icloud"` string'i (UI badge) |

---

## 10. App Silinince Veri Durumu

| Veri | App Silinince | iCloud Restore |
|---|---|---|
| SwiftData SQLite | **Tamamen silinir** | iCloud backup'tan **geri gelebilir** |
| `Documents/VehicleDocuments/` | **Tamamen silinir** | iCloud backup'tan **geri gelebilir** |
| `NSTemporaryDirectory()` PDF | Sistem temizler | Geri gelmez |
| `UserDefaults` | **Tamamen silinir** | iCloud backup'tan **geri gelebilir** |
| Bildirimler | App silinince temizlenir | Geri gelmez |

> ℹ️ `Documents/` dizini iOS tarafından **varsayılan olarak iCloud backup kapsamındadır**. Kullanıcı iCloud yedekleme açtıysa, SwiftData store ve belgeler iCloud'a yedeklenir. Cihaz restore edildiğinde veriler geri gelir.

---

## 11. iCloud Backup / Sync Davranışı

| Özellik | Durum |
|---|---|
| iCloud CloudKit sync | ❌ Kapalı |
| iCloud backup | ✅ Varsayılan (Documents/ yedeklenir) |
| iCloud Drive | ❌ Kullanılmıyor |
| NSPersistentCloudKitContainer | ❌ Kullanılmıyor |

**Sonuç:** Veriler cihazda kalır, iCloud sync yoktur, ancak iCloud yedekleme kapsamındadır.

---

## 12. PrivacyInfo.xcprivacy

| Durum | ❌ **MEVCUT DEĞİL** |
|---|---|

`PrivacyInfo.xcprivacy` dosyası projede bulunmuyor. **App Store submission için zorunludur** (Apple, Mayıs 2024'ten beri tüm yeni uygulamalar için şart koşuyor).

---

## 13. App Store Privacy Metni (Önerilen)

```
Ruhsatım hiçbir kullanıcı verisini toplamaz, üçüncü taraflarla paylaşmaz
veya cihaz dışına çıkarmaz. Tüm veriler yalnızca cihazınızda saklanır.
Uygulama tarafından oluşturulan belgeler (satış dosyası PDF'i) yalnızca
sizin başlattığınız paylaşım işlemiyle iletilir.

Uygulamanın topladığı veri tipleri:
- Araç bilgileri (plaka, marka, model, km) — yalnızca cihazda
- Finansal veriler (masraf tutarları) — yalnızca cihazda
- Belgeler (fotoğraf, PDF) — yalnızca cihazda
- Hatırlatıcı tarihleri — yalnızca cihazda

App silindiğinde tüm veriler cihazdan kaldırılır.
iCloud yedekleme açıksa, verileriniz standart iOS yedekleme
kapsamında iCloud'a yedeklenebilir.
```

---

## 14. Genel Değerlendirme

| Kriter | Durum | Not |
|---|---|---|
| Veri depolama | Yalnızca cihaz içi sandbox | ✅ |
| Dış bağımlılık | 0 (sıfır) | ✅ |
| Ağ isteği | 0 | ✅ |
| Analytics / Crash SDK | Yok | ✅ |
| CloudKit sync | Kapalı | ✅ (bilinçli) |
| Ödeme | StoreKit 2 (native) | ✅ |
| Belge silme → disk temizliği | ✅ | Belge bazlı doğru |
| Cascade delete | ⚠️ | Manuel, kapsamlı ama fiziksel dosya temizlemiyor |
| PrivacyInfo.xcprivacy | ❌ Yok | App Store için zorunlu |
| iCloud yedekleme | Varsayılan | Documents/ yedeklenir |
| TestFlight'a çıkabilir mi? | ⚠️ | PrivacyInfo.xcprivacy eklendikten sonra |

---

## 15. Aksiyon Maddeleri

| # | Madde | Öncelik |
|---|---|---|
| 1 | `PrivacyInfo.xcprivacy` oluştur | 🔴 Critical — App Store şartı |
| 2 | `VehicleDetailView.deleteVehicle()` → fiziksel belge temizliği ekle | 🟡 Medium |
| 3 | `Documents/VehicleDocuments/` URL'ini `isExcludedFromBackup` ile iCloud backup'tan çıkar (opsiyonel) | 🟢 Low |
