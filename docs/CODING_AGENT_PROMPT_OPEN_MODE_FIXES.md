# Coding Agent Prompt — Açık Mod Border + Subtle Fill Fix

> Bu prompt, TestFlight internal testing'e göndermeden **hemen önce** uygulanması gereken açık mod görsel fix'ini tarif eder.
> Ön koşul: Mevcut MVP build (`ee78bee`) yeşil, 151 test geçiyor.
> Karar manifestosu: `docs/STRATEGIC_DECISIONS_MVP.md` Karar 4.1.
> İlgili görsel kanıt: Kullanıcı tarafından paylaşılan 4 ekran görüntüsünde "Satış Dosyası" kartı, rehber kartları ve Dosya Skoru kartı gibi birçok card'ın açık modda border'ı görünmüyor.

---

## Context

Kullanıcı TestFlight öncesi son görsel incelemede fark etti: açık modda beyaz zemin üstünde birçok card'ın border'ı görünmüyor. Önceki fix'te border rengini `#D1D1D6 → #C7C7CC`'ye çekmiştik — yetersiz kaldı, üstüne bir de `.opacity(0.4-0.5x)` çarpanı eklenince border tamamen silikleşti.

3 seçenek tartışıldı, kullanıcı **Seçenek 2 (Border + Subtle Fill)**'yi seçti:
1. ~~Sadece border koyulaştır~~ → yetersiz
2. **Border + Subtle Fill** → card zemin `#FAFAFA`, border `#AEAEB2`
3. ~~Sadece fill + shadow~~ → TestFlight öncesi riskli

Sonuç: Açık modda tüm card'lar subtle ama net biçimde zeminden ayrılacak, koyu mod görsel olarak etkilenmeyecek.

---

## Hard constraints (BUNLARI İHLAL ETME)

- ❌ Mevcut MVP davranışını değiştirme. Sadece **görsel** fix.
- ❌ Dark mode asset'lerine dokunma (zaten doğru, korunacak).
- ❌ Card layout, padding, spacing, radius değiştirme. Sadece **renk + opacity**.
- ❌ Yeni asset ekleme. Mevcut 2 renk (Border, SurfacePrimary) güncellenecek.
- ❌ SPM dependency ekleme, yeni framework import etme.
- ❌ `Configuration/`, `build/`, `docs/` (bu dosya dışı), `.xcconfig`, `.xcprivacy`, `.entitlements`, `Info.plist`, `.pbxproj` değiştirme.
- ❌ Mevcut testleri silme/geçersiz kılma. Yeni test ekleme sadece doğrulama için.
- ❌ Card'ları `Material` (`.background(.regularMaterial)` vb.) yapma. Bu AI-slop. Düz renk kalacak.
- ❌ `01_DESIGN.md` veya `docs/STRATEGIC_DECISIONS_MVP.md` Karar 4.1'i değiştirme. Manifesto kanundur.

## Soft constraints

- Her değişiklik sonrası `xcodebuild test` çalıştır, 151 test geçmeli.
- Tek commit, açıklayıcı mesaj: `fix(open-mode): subtle card fill + stronger border (karar 4.1)`.
- Bu prompt tek PR'da tamamlanacak. Branch'e gerek yok, doğrudan `main`'e.
- Build'de dark-only preview ile son kontrol yap.

---

# Fix 4.1.1 — Asset Catalog: Border + SurfacePrimary renkleri

**Karar:** `docs/STRATEGIC_DECISIONS_MVP.md` Karar 4.1.

**Dosyalar:**
- `Resources/Assets.xcassets/Border.colorset/Contents.json`
- `Resources/Assets.xcassets/SurfacePrimary.colorset/Contents.json`

**Mevcut durum:**
- `Border` light: `#C7C7CC` (RGB 0.780, 0.780, 0.800) — beyaz üstünde yetersiz
- `Border` dark: `#3A3A3A` (RGB 0.227, 0.227, 0.227) — dokunma
- `SurfacePrimary` light: `#FFFFFF` (RGB 1, 1, 1) — BackgroundPrimary ile aynı, card'lar zeminden ayrılmıyor
- `SurfacePrimary` dark: `#2E2E2E` (RGB 0.180, 0.180, 0.180) — dokunma

**Yapılacak:**

### Border.colorset/Contents.json

Light variant'taki `components` değerlerini değiştir:
```json
"components": {
  "alpha": "1.000",
  "blue": "0.698",
  "green": "0.682",
  "red": "0.682"
}
```

Bu = `#AEAEB2` (iOS standard separator tonu). Dark variant'a dokunma.

### SurfacePrimary.colorset/Contents.json

Light variant'taki `components` değerlerini değiştir:
```json
"components": {
  "alpha": "1.000",
  "blue": "0.980",
  "green": "0.980",
  "red": "0.980"
}
```

Bu = `#FAFAFA`. BackgroundPrimary (`#FFFFFF`) ile 1 tonal step fark oluşturacak — card'lar subtle ama algılanabilir biçimde zeminden ayrılacak. Dark variant'a dokunma.

**Acceptance criteria:**
- `xcodebuild` asset catalog'u parse edebiliyor, hata yok.
- Açık modda `Color.appSurface` artık `#FAFAFA`, koyu modda hâlâ `#2E2E2E`.
- Açık modda `Color.appBorder` artık `#AEAEB2`, koyu modda hâlâ `#3A3A3A`.

---

# Fix 4.1.2 — Border opacity'leri güçlendir

**Karar:** `docs/STRATEGIC_DECISIONS_MVP.md` Karar 4.1.

**Dosyalar (25 satır, 7 dosya):**

```
Features/VehicleDetail/VehicleDetailView.swift          (12 satır)
Features/Garage/GarageView.swift                        (5 satır)
Features/Reports/ReportsView.swift                      (4 satır)
Features/Reminders/ReminderListView.swift               (1 satır)
DesignSystem/Components/OwnershipInsightCard.swift      (1 satır)
```

**Mevcut durum:** Tüm card stroke'lar `AppColors.border.opacity(0.4-0.6x)` aralığında. Yeni `#AEAEB2` renge rağmen bu opacity'ler hâlâ soluk kalabilir — özellikle `0.42` (8 yerde) ve `0.45` (8 yerde) çok düşük.

**Yapılacak:**

Aşağıdaki eşleme tablosuna göre **her satırı** güncelle. `border.opacity(X)` → `border.opacity(Y)`:

| Eski | Yeni | Nerede |
|------|------|--------|
| `opacity(0.35)` | `opacity(0.85)` | GarageView L733 (normal stroke 0.5pt) |
| `opacity(0.35)` | `opacity(0.70)` | VehicleDetailView L893 (**timeline ring, 3.5pt — kalın, düşük tutulmalı**) |
| `opacity(0.40)` | `opacity(0.85)` | GarageView L424 |
| `opacity(0.42)` | `opacity(0.85)` | VehicleDetailView L493, L704, L788, L935, L1269; ReminderListView L115 |
| `opacity(0.45)` | `opacity(0.85)` | VehicleDetailView L587, L1424; ReportsView L354, L398, L481, L568; OwnershipInsightCard L120 |
| `opacity(0.50)` | `opacity(0.85)` | VehicleDetailView L254, L365 |
| `opacity(0.55)` | `opacity(0.85)` | GarageView L691 |
| `opacity(0.60)` | `opacity(0.85)` | GarageView L481 |

**Önemli:** Aşağıdaki 3 satıra **dokunma** — bunlar milestone timeline dot'ları, farklı semantik (opacity zaten ≥ 0.72):

```
VehicleDetailView.swift
  L1584: .fill(event.isMilestone ? AppColors.accentPrimary.opacity(0.28) : AppColors.border.opacity(0.72))
  L1600: .stroke(event.isMilestone ? AppColors.accentPrimary.opacity(0.24) : AppColors.border.opacity(0.8), lineWidth: 1)
  L1605: .fill(AppColors.border.opacity(0.72))
```

**Doğrulama:** Tüm değişikliklerden sonra `grep -rn "AppColors.border.opacity(0\." Features/ DesignSystem/` çalıştır. Sonuçta şunlar görünmeli:
- 3 dokunulmamış satır (0.72-0.8 opacity, milestone)
- L893 → 0.70
- Geri kalan 21 satır → 0.85

**Acceptance criteria:**
- 25 satırdan 22'si güncellendi (3 dokunulmadı).
- `grep` ile doğrulandı, eski opacity'ler kalmadı.
- Açık modda "Satış Dosyası" kartı, rehber kartları, Dosya Skoru kartı görünür border'a sahip.
- Card zemin `#FAFAFA` ile sayfa zemini `#FFFFFF` arasında subtle ama algılanabilir ayrım var.

---

# Fix 4.1.3 — Smoke doğrulama

**Karar:** `docs/STRATEGIC_DECISIONS_MVP.md` Karar 4.1.

**Yapılacak:**

1. **Test çalıştır:** `xcodebuild test -scheme Garajim -destination 'platform=iOS Simulator,name=iPhone 15'`. 151 test geçmeli.

2. **Görsel smoke test:** Simulator'da dark-only preview. Şu sayfalara bak:
   - **Garaj** (`Features/Garage/GarageView.swift`) → hero card, bugün section, rehber kartları
   - **Araç Detay** (`Features/VehicleDetail/VehicleDetailView.swift`) → hero, sıradaki işler, timeline, rehber
   - **Raporlar** (`Features/Reports/ReportsView.swift`) → özet kartları

3. **Kontrol listesi (dark-only):**
   - [ ] Hero card altın border ile ayrılıyor
   - [ ] "Satış Dosyası" CTA kartı border görünür
   - [ ] Rehber kartları border görünür
   - [ ] Dosya Skoru kartı border görünür
   - [ ] Milestone timeline dot'ları stroke görünür
   - [ ] Empty state satırları (henüz kayıt yok vb.) borderless
   - [ ] Tüm kartlar koyu zeminde okunabilir
   - [ ] Gold accent tutarlı

---

## Notlar

- Bu fix **görsel** nitelikte, **davranış** değişmiyor. Acceptance criteria görsel + test sayısı.
- TestFlight internal testing'e gönderilecek build'de **bu commit mutlaka** olmalı. Yoksa tester'lar açık modda kötü ilk izlenim alır.
- İleride (v1.1 veya sonrası) card sistemine `surfaceSecondary` veya subtle shadow eklenirse bu değerler tekrar gözden geçirilebilir — şimdilik en stabil denge bu.