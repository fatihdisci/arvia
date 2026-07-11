# Arvia — Tanıtım Videosu (HyperFrames)

Arvia iOS uygulaması için 9:16 dikey, 30 saniyelik tanıtım videosu. HyperFrames kompozisyonu: plain HTML + GSAP timeline.

## Kompozisyon özeti

- **Çözünürlük:** 1080 × 1920 (9:16 dikey, Reels/TikTok formatı)
- **Süre:** 30 saniye
- **Sahne sayısı:** 9
- **Shader transition:** 3 adet (hero reveal, enerji shift, CTA landing)
- **Render:** `npx hyperframes render index.html -o output.mp4`

## Sahne akışı

| # | Süre | Sahne | Transition |
|---|------|-------|-----------|
| 1 | 0-3s | Açılış — ARVİA wordmark, reticle motif | hard cut |
| 2 | 3-6s | Problem — "Aracının belgeleri hâlâ çekmecende mi?" | hard cut |
| 3 | 6-9s | Garaj — araç kartları | **SHADER** cinematic-zoom |
| 4 | 9-12s | Hero — dosya tamlık skoru takometre gauge | **SHADER** whip-pan |
| 5 | 12-15s | Hatırlatıcılar — muayene, sigorta, MTV | **SHADER** cross-warp-morph |
| 6 | 15-19s | Masraf & bakım — yıllık özet + bar chart | hard cut |
| 7 | 19-22s | Belge kasası — 2×3 grid | hard cut |
| 8 | 22-26s | Satış dosyası — PDF mockup + QR | hard cut |
| 9 | 26-30s | CTA — "YAKINDA App Store'da" | final |

## Gereksinimler

- **Node.js 22+** — [nodejs.org](https://nodejs.org/)
- **FFmpeg** — `brew install ffmpeg` (macOS) veya [ffmpeg.org/download](https://ffmpeg.org/download.html)

Kurulumu doğrula:

```bash
npx hyperframes doctor
```

## Preview (frame-accurate scrubbing)

```bash
npx hyperframes preview
```

`http://localhost:3002` üzerinde HyperFrames Studio açılır. Sahne ilerlemesini kare kare kontrol edebilirsin.

## Render

```bash
npx hyperframes render index.html -o output.mp4
```

Varsayılan: 30fps. 60fps için:

```bash
npx hyperframes render index.html -o output.mp4 --fps 60
```

## Lint

```bash
npx hyperframes lint
```

Sıfır hata beklenir. Sahne yapısı, shader invariant'ı ve timeline bütünlüğü otomatik kontrol edilir.

## Marka bağlamı

Bu video, **Arvia** iOS uygulamasının ("Ruhsatim" çalışma adı) tanıtım filmidir. Tasarım dili:

- **Cockpit Black canvas** — gerçek siyah (#000000) AMOLED zemin
- **Turkuaz tek aktif vurgu** — #00E5C7 (CTA, aktif durum, canlı metrik)
- **JetBrains Mono** — teknik veri, plaka, tutar, km okumaları
- **Reticle köşe motifi** — araç fotoğrafı ve önemli veri çerçevelerinde kullanılan imza motifi
- **Takometre gauge** — skorlar için imza grafik (yarım daire, ibreli)

Detaylar için `DESIGN.md` dosyasına bak.

## Dosya yapısı

```
arvia-intro-video/
  index.html      # ana kompozisyon
  preview.html    # HyperFrames Studio player
  README.md       # bu dosya
  DESIGN.md       # marka & motion kararları
```
