# Records Segment Bar Fix

**Tarih:** 2026-07-05
**Branch:** main
**Commit aralığı:** f58705a (revert) → bu fix

## Problem

Kayıtlar (Records) sekmesinde "Geçmiş" seçiliyken segment control (Geçmiş/Raporlar Picker) nav bar alanına "yutuluyordu". "Raporlar" seçiliyken sorun yoktu — çünkü Raporlar `List` değil `ScrollView` kullanıyor.

## Kök Neden

`RecordsView.swift`, segment Picker'ı kendi `Group`'unun `.safeAreaInset(edge: .top)`'inde tutuyordu. Bu, `HistoryView`'ın içindeki `List`'ten bir seviye uzakta. `List`, kendi üst güvenli alanını nav bar'a göre otomatik yeniden hesapladığı için, doğrudan kendisini sarmayan safeAreaInset içeriğini üst bara "yutuyor". Aynı hata daha önce HistoryView'ın kendi filtre çiplerinde de vardı ve commit 56051b7 ile çözülmüştü.

## Çözüm

Segment Picker, `RecordsView`'ın dış safeAreaInset'inden çıkarılıp, her iki alt view'ın (`HistoryView`, `ReportsView`) kendi **doğrudan** List/ScrollView'ü saran safeAreaInset'ine taşındı. Bu, 56051b7'de filtre çipleri için uygulanan aynı desen.

Segment seçimi (`Segment`) artık `@Binding` ile alt view'lara geçiliyor, paylaşılan `RecordsSegmentPicker` komponenti üzerinden render ediliyor.

## Değişen Dosyalar

| Dosya | Değişiklik |
|-------|-----------|
| `Features/Records/RecordsView.swift` | Segment Picker + safeAreaInset kaldırıldı; `HistoryView`/`ReportsView`'a `segment` binding olarak geçiliyor; `RecordsSegmentPicker` paylaşımlı komponenti eklendi |
| `Features/Records/HistoryView.swift` | `@Binding var segment` eklendi; safeAreaInset'e `RecordsSegmentPicker` ilk eleman olarak eklendi; yorumlar güncellendi; Preview'lar `.constant(.archive)` ile güncellendi |
| `Features/Reports/ReportsView.swift` | `@Binding var segment` eklendi; `init(segment:)` eklendi; yeni `.safeAreaInset(edge: .top)` eklendi; yorumlar güncellendi; Preview'lar `.constant(.reports)` ile güncellendi |

## Doğrulama

### Build

| Metrik | Sonuç |
|--------|-------|
| Durum | **BUILD SUCCEEDED** |
| Hata | 0 |
| Uyarı (yeni) | 0 |

### Test

| Metrik | Sonuç |
|--------|-------|
| Toplam test | 229 |
| Geçen | 223 |
| Kalan | 6 (tümü `PaywallLimitTests` — bu değişiklikle ilgisiz, önceden var olan hatalar) |
| Bu fix'ten etkilenen test | 0 |

### Statik Kontroller

| Kontrol | Sonuç |
|---------|-------|
| `RecordsSegmentPicker` HistoryView.swift'te referanslı | ✅ |
| `RecordsSegmentPicker` ReportsView.swift'te referanslı | ✅ |
| Sıfır argümanlı `HistoryView()` çağrısı kaldı | ✅ (0 eşleşme) |
| Sıfır argümanlı `ReportsView()` çağrısı kaldı | ✅ (0 eşleşme) |
| `.navigationTitle("Kayıtlar")` korundu | ✅ |
| `.toolbarTitleDisplayMode(.inlineLarge)` korundu | ✅ |
| `ToolbarItem(placement: .principal)` yok | ✅ |
| `.navigationBarTitleDisplayMode` yok | ✅ |

## Manuel Kontrol (Kullanıcı)

- [ ] Segment control "Kayıtlar" büyük başlığının hemen altında duruyor
- [ ] "Geçmiş" seçiliyken segment control nav bar'a kaçmıyor (kayıt varken ve boş state'te)
- [ ] "Raporlar" seçiliyken görünüm eskisi gibi
- [ ] İki segment arasında geçişte sıçrama/titreme yok
