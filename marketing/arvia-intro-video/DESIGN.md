# Arvia Intro Video — Tasarım Kararları

## 1. Format

- **En-boy oranı:** 9:16 (dikey, mobil)
- **Çözünürlük:** 1080 × 1920
- **Süre:** 30 saniye
- **Hedef platformlar:** Instagram Reels, TikTok, YouTube Shorts, App Store önizleme

## 2. Marka kimliği

Video, Arvia iOS uygulamasının mevcut tasarım anayasasını birebir yansıtır. Tasarım dosyaları: `01_DESIGN.md` (proje kökü).

### Renkler

| Token | Değer | Kullanım |
|---|---|---|
| `--bg` | `#000000` | AMOLED siyah canvas |
| `--surface` | `#121214` | Kart yüzeyleri |
| `--ink` | `#f5f5f7` | Birincil metin (soft white) |
| `--text-secondary` | `#9a9aa0` | İkincil metin |
| `--text-tertiary` | `#6e6e73` | Muted, etiket |
| `--accent` | `#00e5c7` | **TEK aktif vurgu** — CTA, aktif durum, canlı metrik |
| `--accent-2` | `#33edd4` | Açık turkuaz — gradient/highlight |
| `--critical` | `#ff2d3c` | Racing kırmızı — yalnızca acil/muayene gibi kritik semantik |
| `--border` | `#2a2a2c` | 1px nötr hairline çerçeve |

### Tipografi

| Token | Font | Ağırlık | Kullanım |
|---|---|---|---|
| Display | Manrope | 300/600/800 | Başlıklar, wordmark, UI metni |
| Mono | JetBrains Mono | 300/400/700 | Plaka, tutar, km, gün, statü |

Manrope + JetBrains Mono kombinasyonu:
- Manrope: modern, geometrik, orta-yumuşak. "Kokpit" hissi için yeterince teknik, "AI-slop" için yeterince özgün.
- JetBrains Mono: design anayasasının zorunlu veri fontu; terminal/odometre estetiği burada da geçerli.

Hiçbir yerde Inter/Roboto/Arial kullanılmaz.

## 3. Sahne kompozisyonu

Her sahnede:
- Eyebrow (label-caps, 18px, accent veya muted)
- Başlık (display, 80-220px, beyaz)
- İçerik (kart, liste, chart, gauge)
- Hairline çerçeveler (1px nötr — turkuaz değil)

Açılış ve CTA sahnelerinde reticle köşe motifi (imza).

## 4. Motion prensipleri

- **Eğriler:** 3+ farklı ease her sahnede (`power2.out` smooth, `expo.out` dramatic, `back.out` bouncy, `sine.inOut` dreamy).
- **Stagger:** Karakter/kart/satır geçişlerinde 0.08-0.18s.
- **Counter animasyonları:** Sayaçlar `power2.out` veya `expo.out` ile 0.8-1.4s'de yumuşak yükselir.
- **Mid-scene activity:** Her sahne en az bir nefes/glow/sweep içerir — JPEG hissi yok.
- **Hard cut ağırlıklı:** 9 sahnede yalnızca 3 shader. Shader yalnızca hero reveal (s3→s4), enerji shift (s4→s5) ve CTA landing (s5→s6) için — geri kalanı hard cut.

## 5. Shader seçimi

| Transition | Shader | Neden |
|---|---|---|
| s3→s4 (garaj → hero gauge) | `cinematic-zoom` | Hero anı, ürünün imza motifi (takometre) ortaya çıkıyor |
| s4→s5 (gauge → hatırlatıcı) | `whip-pan` | Enerji shift, hızlı bilgi akışına geçiş |
| s5→s6 (hatırlatıcı → masraf) | `cross-warp-morph` | Veri yoğunluğu geçişi, yumuşak ama fark edilir |

s6'dan sonra 3 sahnede hard cut (belge, satış dosyası, CTA) — toplam 8 cut, 3 shader. Shader aşırı kullanımından kaçınıldı.

## 6. Anti-AI-slop kontrolleri

- ❌ Mavi-mor gradient yok
- ❌ Glassmorphism yok
- ❌ Her sahnede aynı kart grid yok
- ❌ Emoji ikon yok
- ❌ 3D illüstrasyon yok
- ❌ Generik SaaS kart yığını yok
- ✅ Tek tip 6px radius (HUD/kokpit hissi, 10px+ yumuşak yuvarlak değil)
- ✅ Sadece 2 renk ailesi: siyah/griler + turkuaz + 1 spot kritik kırmızı (sadece acil muayene)
- ✅ Tabular numerals (font-variant-numeric) her sayı kolonunda
- ✅ Hairline border-based elevasyon, gölge yok

## 7. Determinism

- `Math.random()` yok
- `Date.now()` / `performance.now()` yok
- Tüm zamanlama hard-coded timeline pozisyonlarında
- `setInterval` / `setTimeout` / `requestAnimationFrame` yok — tüm motion GSAP timeline'da

## 8. Bilinen eksikler / sonraki adımlar

- Takometre gauge'de ibre animasyonu (needle) statik — sweep hareketinin ardından eklenebilir
- Belge kasası grid'inde dosya tip ikonları şu an metin + numara ile temsil ediliyor; SVG ikonlar (SF Symbols eşdeğeri) ile zenginleştirilebilir
- s9 CTA sahnesinde App Store badge yok — şu an "YAKINDA App Store'da" metni. Lansman öncesi badge eklenecek
- Tüm veriler placeholder (gerçek Arvia verisi değil); final versiyonda gerçek kullanıcı anonimleştirilmiş verileri kullanılacak
- Müzik/audio track ayrıca eklenebilir (`<audio>` element, HyperFrames dış render pipeline'ında)

## 9. Render pipeline notları

`npx hyperframes render index.html -o output.mp4` çağrısı:

- 1080×1920, 30fps, 30 saniye = 900 frame
- WebGL shader transitions browser'da çalışır; render ederken WebGL context Chromium-headless üzerinden
- Tahmini render süresi: 5-15 dakika (sahne sayısı ve shader karmaşıklığına göre)

60fps gerekiyorsa `--fps 60` ekle (boyut iki katına çıkar).
