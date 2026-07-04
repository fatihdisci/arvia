# Tasarım Denetimi + Düzeltme — Round 2 (Cockpit Black)

**Tarih:** 2026-07-04
**Kapsam:** Son 10 commit'in (78f8fdd..61a0160) denetimi + 35 maddelik düzeltme listesi + imza grafik yönergesi (takometre gauge, hairline border, keskin köşe, reticle).

---

## Kök Neden Bulgusu

**Alt bar aktif sekme rengi eskiden kalmıştı (madde 35c):** `App/VehicleDossierApp.swift` içindeki `configureAppearance()` UIKit seviyesinde **altın (#E6C479) + navy (#0F131F)** hardcode ediyordu — reskin `UIColor(red:...)` formatını yakalayamamıştı. Turkuaz/siyah/hairline'a çevrildi (tab bar + segmented control).

## Yeni İmza Bileşenler

| Bileşen | Dosya | Ne yapar |
|---|---|---|
| `TachometerGauge` | `DesignSystem/Components/TachometerGauge.swift` | Yarım daire takometre: 21 tik (5'lik minor, 25'lik major), ibre + hub, animasyonlu dolum, mono okuma. `DossierCompletenessCard` + `FileCompletenessCard`'a bağlandı (önceki yarım-yay tiksiz/ibresizdi; FileCompletenessCard'da gauge hiç yoktu) |
| `ReticleCorners` | `DesignSystem/Components/ReticleCorners.swift` | Köşe ayraç/nişangah motifi — `VehicleDetailHero` fotoğraf kartına uygulandı |

İkisi de pbxproj'a 4 noktadan kaydedildi (plutil OK).

## Token Değişimleri

| Token | Eski | Yeni |
|---|---|---|
| `AppColors.border` | #00E5C7 @ %15 (turkuaz) | **#2A2A2C nötr hairline** — HUD hissi; turkuaz artık yalnızca aktif vurgu |
| `AppRadius.large` (kartlar) | 8 | **6** |
| `AppRadius.xlarge` (hero) | 12 | **10** |
| UIKit tab bar selected | altın #E6C479 | turkuaz #00E5C7 |
| UIKit tab bar zemin | navy #0F131F | siyah #0A0A0A |

## 35 Madde — Durum Tablosu

| # | Madde | Durum |
|---|---|---|
| 1 | Tab bar inset | ✅ ReminderDetailView'a 72pt eklendi; diğer 5 ekranda zaten vardı (doğrulandı) |
| 2 | a11y etiketleri | ✅ Garaj chevron'ları ("Önceki/Sonraki araç"), "Garaj Seçenekleri", "Gönderi Seçenekleri", sheet × ("Öneriyi kapat") |
| 3 | Empty state ikonları soluk | ✅ Turkuaz muted daire + accent ikon (EmptyStateView — tüm boş ekranlar) |
| 4 | Fotoğrafta plaka yok | ✅ Yarı transparan mono plaka rozeti (sol alt) |
| 5 | Dosya Skoru çift görsel | ✅ Önceki commit'te çözülmüş (646736f) — tek yüzey, doğrulandı |
| 6 | Hızlı İşlemler kesik | ✅ Önceki commit'te 2 sütun (76acbe5) + inset mevcut — doğrulandı |
| 7 | "Hatırlat" kısaltması | ✅ Önceki commit'te "Hatırlatıcı Ekle" — doğrulandı |
| 8 | Çift ellipsis | ✅ Kaynak metinde "..." yok; carousel refactor sonrası tek truncation — doğrulandı |
| 9 | → tek başına | ✅ "DETAY" tracked mikro-etiket + turkuaz |
| 10 | Mock timeline soluk | ✅ İç opaklıklar 0.3→0.5 / 0.6→0.85 / 0.2→0.35, dış 0.72 |
| 11 | ÖRNEK amber | ✅ Nötr (textSecondary + hairline) |
| 12 | Kimlik/Belge chip tutarsız | ✅ Tamam=✓+turkuaz muted; eksik=kesikli daire+nötr |
| 13 | "Bu Yıl" grubu kayıp | ✅ Boşken "Bu Yıl · 0" başlığı + sakin bilgi satırı (uzak vade varken) |
| 14 | Stats 0/0/0 | ✅ "Önümüzdeki 30 günde iş yok — her şey yolunda." pozitif özet |
| 15 | Uzak vade ikon soluk | ✅ 30+ gün: turkuaz %55 ("uzak ama aktif") |
| 16 | Yuvarlak geri ok | ⚪ SİSTEM — iOS 26 Liquid Glass native back butonu; kodda custom yok, HIG'e müdahale önerilmez |
| 17 | Edit yeşil | ✅ Önceden düzeltilmiş (accentPrimary) — doğrulandı |
| 18 | Düzenle/Sil kesik | ✅ Alt inset 48→72pt |
| 19 | Mini tur 3. adım kesik | ✅ Önceki commit'te safeAreaPadding — doğrulandı |
| 20 | "Ekle" filled görünüyor | ✅ `.borderless` — iOS 26 confirmationAction cam kapsülü kaldırıldı |
| 21 | Kategori grid sıkışık | ✅ Min hücre 64→72, esnek genişlik, label 10pt + ölçekleme |
| 22 | Seçili kategori filled | ✅ Outline + muted dolgu + ✓ ikonu + isSelected trait |
| 23 | Filter chips kesik | ✅ Sağ kenar fade ("devamı var" sinyali) |
| 24 | Topluluk %60 boş | 🔶 ERTELENDİ — örnek post preview'lı güçlü empty state ayrı iş (CommunityEmptyStateView) |
| 25 | Apple butonu küçük | ✅ Toolbar mini butonu kaldırıldı → "Giriş Yap" → sheet'te tam genişlik Apple butonu (HIG) |
| 26 | Drag indicator | ✅ Önceki commit'te eklenmiş — doğrulandı |
| 27 | Sheet alt kesik | ✅ Native sheet + medium detent (tab bar'ı kapatır) — carousel refactor'la çözülmüş |
| 28 | × küçük, label yok | ✅ 44pt tap target + "Öneriyi kapat" |
| 29 | = 16 | ⚪ SİSTEM |
| 30 | Nav header padding | ⚪ SİSTEM (iOS 26 nav yerleşimi) |
| 31 | Plaka chip silik | ✅ Opak zemin + hairline + tracking; kapsül→dikdörtgen (plaka formu) |
| 32 | "Ekle" rengi tutarsız | ✅ Toolbar Ekle turkuaz + borderless |
| 33 | Grid divider zayıf | ✅ Rectangle #2A2A2C 1px |
| 34 | Subtitle font tutarlılığı | 🔶 ERTELENDİ — kapsamlı sweep ayrı iş, görsel risk düşük |
| 35 | Placeholder ikonlar + Apple border + tab rengi | ✅ EmptyStateView markalı; Apple border sorunu butonla birlikte kalktı; tab bar aktif rengi turkuaz (kök neden yukarıda) |

## Tasarım Yönergesi — Durum

| İş | Durum |
|---|---|
| Yarım daire takometre (tik + ibre + animasyon) | ✅ TachometerGauge — 2 kartta canlı |
| Kart köşe 4-6pt | ✅ 6pt (hero 10pt) |
| Soft shadow yerine hairline #2A2A2C | ✅ Token değişimi — tüm kartlar otomatik |
| Bordered + uppercase + tracked primary CTA | ✅ Pass 1'de yapılmıştı — doğrulandı |
| Köşe reticle motifi | ✅ ReticleCorners — hero fotoğrafta; tarama/foto çekme akışlarına da uygulanabilir |

## Doküman Güncellemeleri

`01_DESIGN.md` §5 (border #2A2A2C), §8 (radius 6/10), §9 (hairline elevasyon), §12 (TachometerGauge + ReticleCorners eklendi), §13 (input idle hairline), §14 (tab bar hairline üst çizgi).

## Doğrulama

- **Build:** SUCCEEDED
- **Test:** 151/151 passed — 0 failure
- **plutil -lint:** OK (2 yeni dosya kaydı sonrası)

## Açık Kalanlar (bilinçli)

1. **Madde 24** — Topluluk guest empty state'ine 3 örnek post preview: ayrı tasarım işi.
2. **Madde 34** — caption/secondarySmall tutarlılık sweep'i.
3. **Madde 16/29/30** — iOS 26 sistem navigasyonu; özelleştirme istenirse ayrı araştırma gerekir (önerilmez).
4. Simulator'da gözle doğrulama — özellikle: takometre gauge iki kartta, reticle + plaka rozeti hero'da, tab bar turkuaz aktif ikon, boş Yapılacaklar pozitif özeti.
