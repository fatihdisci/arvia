# Post-Merge Doğrulama Denetimi — Ruhsatım

**Tarih:** 24 Haziran 2026
**Commit:** `78d3506`
**Branch:** main
**Xcode:** 26.5 (17F42)
**Simulator:** iPhone 17e, iOS 26.5

---

## 1. Git Durumu

| Kontrol | Sonuç |
|---|---|
| Branch | `main` |
| Status | Clean (nothing to commit) |
| Remote | `git@github.com:fatihdisci/arac.git` |
| HEAD | `78d3506` |

```
78d3506 docs: veri saklama mimarisi denetimi — Privacydatabasenotes.md
9480287 docs: reports.md güncellendi — build/test doğrulaması eklendi, skor 16/16
d70215f fix: Xcode 26 build + test onarımı
2cb7cc5 QA denetim raporu
6ab1ee8 Faz 13: Cila ve review hardening
```

---

## 2. CloudKit Flag Durumu

```swift
// App/AppEnvironment.swift:13
static let isCloudKitSyncEnabled = false
```

| Bulgu | Detay |
|---|---|
| Tanım | `AppEnvironment.swift:13` |
| Kullanım | **Sıfır** — hiçbir Swift dosyası okumuyor |
| `NSPersistentCloudKitContainer` | Kodda yok |
| `ModelConfiguration` | Düz, CloudKit opsiyonsuz |
| CloudKit branch merge | **Gerçekleşmemiş** |
| Sonuç | `true`/`false` fark etmez, container her zaman yerel |

---

## 3. Build & Test — CloudKit KAPALI

| Test | Sonuç |
|---|---|
| Clean build | ✅ `BUILD SUCCEEDED` |
| Hata | 0 |
| Uyarı | 0 |
| Unit test (33) | ✅ 33/33 `TEST SUCCEEDED` |

---

## 4. Build — CloudKit AÇIK (flag=true)

| Test | Sonuç |
|---|---|
| Build | ✅ `BUILD SUCCEEDED` |
| Capability: iCloud | ❌ Yok |
| Capability: CloudKit container | ❌ Yok (`iCloud.com.ruhsatim.app`) |
| Capability: Background Modes | ❌ Yok |
| Runtime etki | Yok — flag dead code |
| Sonuç | Flag'in compile/runtime etkisi sıfır |

---

## 5. Belge Sync Mantığı (Kod İncelemesi)

| Kontrol | Durum | Açıklama |
|---|---|---|
| `VehicleDocument.fileData` | ❌ Yok | CloudKit external storage için gerekli property tanımlı değil |
| `@Attribute(.externalStorage)` | ❌ Yok | |
| Belge ekleme → disk kopyası | ✅ | `DocumentStorageService.saveFile()` → `Documents/VehicleDocuments/{UUID}.ext` |
| Belge ekleme → DB kaydı | ✅ | `modelContext.insert(doc)` |
| Lazy backfill (eski belgeler) | ❌ | CloudKit kodu merge edilmemiş |
| `fileData`'dan diske materialize | ❌ | Kod yok |
| UI "henüz inmedi" uyarısı | ❌ | Kod yok |
| Belge silme → disk | ✅ | `DocumentStorageService.deleteFile()` doğru sırada |
| Belge silme → DB | ✅ | `modelContext.delete(doc)` |

### Belge silme sırası (doğru):

```swift
// DocumentListView.swift:189-193
try? DocumentStorageService.shared.deleteFile(doc.localFileName)  // 1. disk
modelContext.delete(doc)                                            // 2. DB
try? modelContext.save()
```

---

## 6. Araç Silme → Fiziksel Belge Temizliği

```
VehicleDetailView.deleteVehicle() cascade:
  ✅ Reminder           (vehicleId)
  ✅ Expense            (vehicleId)
  ✅ ServiceRecord      (vehicleId)
  ✅ PartChange         (serviceRecordId)
  ✅ VehicleDocument    (vehicleId) — DB'den silinir
  ✅ InspectionReport   (vehicleId)
  ✅ SaleFile           (vehicleId)
  ❌ Fiziksel belge dosyaları — TEMİZLENMİYOR
```

> `Documents/VehicleDocuments/` altındaki dosyalar araç silinince yetim kalır.
> Sadece `SettingsView.deleteAllData()` tüm klasörü siliyor.

---

## 7. PrivacyInfo.xcprivacy

| Durum | ❌ Mevcut değil |
|---|---|
| Zorunluluk | Apple, Mayıs 2024'ten beri tüm uygulamalar için şart |
| Etki | App Store review'da **red sebebi** |

---

## 8. App Privacy Metni

Mevcut (`AppStoreMetadata.md`):
> "Verilerin cihazında saklanır. Belgelerin yalnızca sen paylaşırsan paylaşılır."

**Değerlendirme:** ✅ CloudKit kapalı olduğu için bu ifade şu an doğru.

CloudKit aktif edildiğinde güncellenmesi gereken metin:
> "Veriler cihazınızda saklanır. iCloud eşzamanlama etkinse, araç kayıtları ve belgeleriniz Apple iCloud hesabınız üzerinden cihazlarınız arasında eşzamanlanır."

---

## 9. Critical Issues

| # | Sorun | Öncelik |
|---|---|---|
| 🔴 C1 | `PrivacyInfo.xcprivacy` yok | App Store red |
| 🔴 C2 | CloudKit sync branch merge edilmemiş, `isCloudKitSyncEnabled` dead flag | Yanıltıcı |

## 10. High Issues

| # | Sorun | Öncelik |
|---|---|---|
| 🟡 H1 | Araç silinince fiziksel belge dosyaları temizlenmiyor | Veri sızıntısı |
| 🟡 H2 | `isCloudKitSyncEnabled` kod tarafından okunmuyor, runtime etkisi yok | Yanıltıcı flag |

## 11. TestFlight Değerlendirmesi

| Mod | Durum | Koşul |
|---|---|---|
| CloudKit kapalı | ✅ Çıkabilir | PrivacyInfo.xcprivacy eklendikten sonra |
| CloudKit açık | ❌ Çıkamaz | Kod merge edilmemiş |

---

## 12. Özet

| Kriter | Sonuç |
|---|---|
| Main güvenli mi? | ✅ Evet |
| Build (CloudKit OFF) | ✅ Temiz |
| Test (33/33) | ✅ Geçti |
| Build (CloudKit ON) | ✅ (etkisiz) |
| Belge ekleme/önizleme/silme | ✅ |
| Araç silme → belge disk temizliği | ❌ |
| PrivacyInfo.xcprivacy | ❌ |
| CloudKit kodu | ❌ Merge edilmemiş |

---

## 13. Aksiyon Maddeleri

| # | Madde | Öncelik | Durum |
|---|---|---|---|
| 1 | `PrivacyInfo.xcprivacy` oluştur | 🔴 Critical | Bekliyor |
| 2 | `VehicleDetailView.deleteVehicle()` → fiziksel belge temizliği ekle | 🟡 High | Bekliyor |
| 3 | CloudKit sync branch'ini merge et | 🟡 High | Bekliyor |
| 4 | `isCloudKitSyncEnabled` flag'ini `VehicleDossierApp` container init'ine bağla | 🟡 High | Bekliyor |
