# ServiceRecordFormView.saveRecord() — Validation Fix

**Tarih:** 2026-07-04
**Dosya:** `Features/ServiceRecords/ServiceRecordFormView.swift`

---

## Değişiklik Özeti

`saveRecord()` metodu artık tüm validasyon hatalarını tek geçişte topluyor (eski davranış: sadece araç seçimi kontrolü, ilk hatada `return`). 8 yeni kural eklendi:

| # | Kural | Hata Mesajı |
|---|-------|-------------|
| 1 | Odometer parse edilemezse | "Kilometre geçerli bir sayı olmalı." |
| 2 | Odometer negatifse | "Kilometre negatif olamaz." |
| 3 | Tarih gelecekteyse | "Bakım tarihi gelecekte olamaz." |
| 4 | İşçilik tutarı parse edilemezse | "İşçilik tutarı geçerli bir sayı olmalı." |
| 5 | Parça tutarı parse edilemezse | "Parça tutarı geçerli bir sayı olmalı." |
| 6 | Toplam tutar parse edilemezse | "Toplam tutar geçerli bir sayı olmalı." |
| 7 | Hatırlatıcı km parse edilemezse | "Sonraki hatırlatıcı km değeri geçerli bir sayı olmalı." |
| 8 | Hatırlatıcı km negatifse | "Sonraki hatırlatıcı km değeri negatif olamaz." |

## Yeni `saveRecord()` Metodu

```swift
private func saveRecord() {
    var errors: [String] = []

    if selectedVehicleId == nil {
        errors.append("Bir araç seçmelisin.")
    }

    let trimmedOdometer = odometerText.trimmingCharacters(in: .whitespaces)
    if !trimmedOdometer.isEmpty {
        if let value = Int(trimmedOdometer) {
            if value < 0 {
                errors.append("Kilometre negatif olamaz.")
            }
        } else {
            errors.append("Kilometre geçerli bir sayı olmalı.")
        }
    }

    if date > Date() {
        errors.append("Bakım tarihi gelecekte olamaz.")
    }

    if !laborCostText.trimmingCharacters(in: .whitespaces).isEmpty && laborCost == nil {
        errors.append("İşçilik tutarı geçerli bir sayı olmalı.")
    }
    if !partsCostText.trimmingCharacters(in: .whitespaces).isEmpty && partsCost == nil {
        errors.append("Parça tutarı geçerli bir sayı olmalı.")
    }
    if !totalCostText.trimmingCharacters(in: .whitespaces).isEmpty && totalCost == nil {
        errors.append("Toplam tutar geçerli bir sayı olmalı.")
    }

    if createNextReminder {
        let trimmedNextKm = nextReminderOdometerText.trimmingCharacters(in: .whitespaces)
        if !trimmedNextKm.isEmpty {
            if let value = Int(trimmedNextKm) {
                if value < 0 {
                    errors.append("Sonraki hatırlatıcı km değeri negatif olamaz.")
                }
            } else {
                errors.append("Sonraki hatırlatıcı km değeri geçerli bir sayı olmalı.")
            }
        }
    }

    guard errors.isEmpty else {
        validationErrors = errors
        return
    }

    guard let vehicleId = selectedVehicleId else { return }

    // ... (kalan kod aynen korundu, değişmedi)
}
```

## Build

**BUILD SUCCEEDED**

## Test

**151/151 passed** — 0 failures.

## git status

```
 M ServiceRecordFormView.swift  ← sadece bu dosya değişti
```

## Notlar

- `parseCost(_:)` değiştirilmedi — sadece mevcut davranışının sessizce `nil` döndüğü durumlar için hata mesajı eklendi.
- Odometer validasyonu sadece negatif kontrolü yapıyor — aracın mevcut kilometresinden düşük değerlere izin var (geçmişe dönük servis kaydı senaryosu).
- Tarih karşılaştırması doğrudan `date > Date()` ile yapılıyor, takvim günü truncation'ı yok.
- `errorSection` (line 274) zaten `validationErrors` dizisindeki tüm hataları gösteriyordu — yeni kod bu özelliği ilk kez tam olarak kullanıyor.
