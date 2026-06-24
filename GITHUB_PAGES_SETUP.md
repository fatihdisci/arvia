# GitHub Pages Kurulumu — Ruhsatım

Bu belge, Ruhsatım uygulamasının Gizlilik Politikası ve Kullanım Koşulları sayfalarını GitHub Pages üzerinde yayınlamak için gerekli adımları içerir.

## Ön Koşul

- Repo: `github.com/fatihdisci/ruhsatim`
- `docs/` klasörü zaten main branch'te mevcut.

## Kurulum Adımları

### 1. GitHub Pages'i Etkinleştir

1. GitHub'da repo sayfasına git: `github.com/fatihdisci/ruhsatim`
2. **Settings** sekmesine tıkla
3. Sol menüden **Pages** seçeneğine tıkla
4. **Source** altında **"Deploy from a branch"** seç
5. **Branch** olarak `main` seç
6. **Folder** olarak `/docs` seç
7. **Save** butonuna tıkla

### 2. Yayının Tamamlanmasını Bekle

- GitHub Pages birkaç dakika içinde siteyi deploy eder.
- Settings → Pages altında şu URL görünür olacak:
  `https://fatihdisci.github.io/ruhsatim/`

### 3. URL'leri Doğrula

Site yayına girdikten sonra şu sayfalar erişilebilir olmalı:

| Sayfa | URL |
|---|---|
| Ana sayfa | `https://fatihdisci.github.io/ruhsatim/` |
| Gizlilik Politikası | `https://fatihdisci.github.io/ruhsatim/privacy.html` |
| Kullanım Koşulları | `https://fatihdisci.github.io/ruhsatim/terms.html` |

### 4. App Store Connect'te Kullan

App Store Connect → App Privacy bölümünde:

- **Privacy Policy URL:** `https://fatihdisci.github.io/ruhsatim/privacy.html`
- **Terms of Service URL (opsiyonel):** `https://fatihdisci.github.io/ruhsatim/terms.html`

## Dosya Yapısı

```
docs/
  index.html      — Ana sayfa, linkler
  privacy.html    — Gizlilik Politikası
  terms.html      — Kullanım Koşulları
```

## Notlar

- Sayfalar Türkçe hazırlanmıştır.
- Tasarım mobil uyumludur.
- Resmî kurum olmadığımız tüm sayfalarda açıkça belirtilmiştir.
- CloudKit şu an kapalı; privacy sayfasında ileride açılabileceği notu yer almaktadır.
- HTML sayfalarında build/test gerekmez — statik dosyalardır.
