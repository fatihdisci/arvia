# Arvia Pro — Değer Önerileri Backlog Raporu

> **Tarih:** 3 Temmuz 2026
> **Hazırlayan:** Fatih + Mavis
> **Kapsam:** 1-1 bireysel kullanıcı, üçüncü kurum entegrasyonu YOK
> **Referans:** `ROADMAP.md` (Faz 3.2 backlog), `01_DESIGN.md`, `Services/PaywallService.swift`

---

## Mevcut Pro Durumu

`PaywallService.proFeatures` (şu an):
- Sınırsız araç
- Araç bazlı bakım ve masraf geçmişi
- Araç bazlı belge kasası
- Çoklu araç garajı
- Tüm araçlar için hatırlatıcılar

**Gözlem:** Pro değerinin büyük kısmı "kaç araç" ekseninde. **Veri derinliği/analizi eksik** — kullanıcı 5 yıl masraf topladığında uygulama ona "şu öneriyi yaparım" demiyor. Bu açığı kapatacak 6 öneri aşağıda.

---

## 1. 🧠 Akıllı Hatırlatıcı Önerisi (km pattern analizi)

**Problem:** Kullanıcı "60.000 km'de triger kontrol et" bilgisine sahip değil, app bilmiyor. Bugün InsightService sadece rule-based, kullanıcının kendi geçmişinden öğrenmiyor.

**Çözüm:** Arka planda çalışan hafif bir analiz: kullanıcının son 3-5 bakım kaydının km aralıklarına bak → "Senin aracın ortalama 8.500 km'de periyodik bakıma giriyor. Bir sonraki tahmini 52.300 km." gibi proaktif bir hatırlatıcı üret.

**UI/UX:** Garage → Bugün Garajında'da (Faz 1.1 rehberinin içinde) yeni bir **insight tipi**: "📊 Bakım Tahmini". İkonu `chart.line.uptrend.xyaxis`. Card tasarımı diğer rehber kartlarıyla aynı (VehicleInsightCard component'i zaten 5 tip destekliyor). CTA: "Hatırlatıcı Oluştur" → reminder eklenir.

**Teknik:**
- `Services/PredictiveMaintenanceService.swift` — yeni dosya
- UserDefaults cache ile 24 saatte bir çalışır (background task değil — app açıldığında lazy compute)
- ServiceRecord üzerinde basit linear regression veya "son 3'ün ortalaması"
- Yeni `VehicleInsightType.predictiveMaintenance` enum case'i
- Faz 1.1 rehberiyle entegre, `contentKind: .info`

**Fayda:** Kullanıcı "bu app benim için düşünüyor" hisseder. Bakım kaçırma azalır → pocket'ta para kalır. **Net retention artışı.**

**Pro değeri:** ⭐⭐⭐⭐⭐ Yüksek — bugünkü rehberin en güçlü uzantısı, somut tasarruf vaat eder.

**Efor:** 1-2 gün (servis + 1 enum case + 1 test + 1 rehber kart metni).

---

## 2. 📈 Yıllık Derin Rapor (vergi + satış hazırlığı)

**Problem:** ReportsView var ama şu an daha çok "KM başı maliyet" gibi tekil metrikler. Yıllık sahiplik özeti sığ. Kullanıcı aracını satarken veya vergi beyannamesi için "2024'te bu araç bana ne kadara mal oldu?" sorusuna somut cevap yok.

**Çözüm:** Yeni ekran: **Raporlar → "Yıllık Sahiplik Özeti"**. Tarih seçici (2024, 2025, 2026...). Çıktılar:
- Toplam masraf (kategori dağılımı — pasta grafik)
- Yakıt tüketimi (L/100km trendi — satır grafik)
- Aylık karşılaştırma (bar — ocak vs şubat)
- En pahalı ay + en pahalı kategori
- Tahmini yıllık değer kaybı (sadece hesap tablosu, garanti yok)
- "Geçen yıla göre %X daha az harcadın" karşılaştırma

**UI/UX:** ReportsView içinde "Yıllık Özet" card'ı. Tıklayınca dedicated sheet/screen. Swift Charts framework (iOS 16+, zaten var). Design anayasası: token renkler (gold accent, koyu yüzey), AI-slop gradient yok. Paylaş butonu → PDF export.

**Teknik:**
- `Services/YearlyReportService.swift` — yeni dosya
- `Features/Reports/YearlyReportView.swift` — yeni ekran
- Expense + ServiceRecord üzerinde aggregation
- Swift Charts: `Chart { ... }` syntax
- PDF: mevcut `PDFExportService` ile entegre, "Yıllık Rapor" şablonu

**Fayda:** Gerçek bir **değer anı** — kullanıcı 1 Ocak'ta "geçen yıl özetim"i görmek ister. Vergi için faydalı (şirket aracıysa). Satış öncesi hazırlık. Paylaşılabilirlik (PDF).

**Pro değeri:** ⭐⭐⭐⭐ Yüksek — somut, paylaşılabilir çıktı, yılda 1-2 kez kullanılır ama her kullanım değerli.

**Efor:** 3-4 gün (chart'lar + PDF + paylaşım + mevcut raporların üstüne ek).

---

## 3. 🔗 Sınırlı Süreli Satış Dosyası Paylaşım Linki

**Problem:** SaleFileView var ama paylaşım için AirDrop veya PDF göndermek gerekiyor. Alıcı "link" isterse yok. Kullanıcı aracını satarken 10 kişiye göndermek zor — dosya gizli kalır, güncelleme yapılırsa eski link expire olmaz.

**Çözüm:** Satış dosyasından **public link** üret. Format: `arvia.app/v/ARV-4X9K`. Link tıklanınca web'de (PWA olmadan) minimal bir görüntüleme sayfası açılır:
- Araç özeti
- Bakım geçmişi özeti
- Son görüntüleme tarihi
- **Son kullanma tarihi** (3 gün, 7 gün, 14 gün — kullanıcı seçer)
- Görüntülenme sayısı (kullanıcı dashboard'undan takip eder)

**UI/UX:** SaleFileView → "Paylaş" butonu → alt menü: "AirDrop", "PDF Kaydet", **"Link Oluştur"** (Pro). Link oluştur → sheet: son kullanma seçenekleri + "Linki Kopyala". Dashboard'da (Pro) link listesi: kim ne zaman görüntüledi.

**Teknik:**
- `Vehicle.publicIdentifier: String` (5+5 char random) — yeni alan, SwiftData migration (default boş)
- `SharedSaleLinkService.swift` — yeni service, Supabase'e link kaydı + expiration logic
- Web endpoint: minimal static HTML (GitHub Pages'de host edilebilir — mevcut `privacy.html`, `terms.html` aynı yerde)
- Realtime: `viewCount` increment + `lastViewedAt` update

**Fayda:** Alıcıya profesyonel his — "Arvia kullanıyorum, link bu, 3 gün geçerli" → güven artışı. Kullanıcı kontrol eder (son kullanma). Tek tuşla paylaşım. **Araç satış sürecini kolaylaştırır.**

**Pro değeri:** ⭐⭐⭐⭐ Yüksek — somut dönüşüm anı (araç satarken). Web tarafı ucuz (static site), backend Supabase zaten var.

**Efor:** 4-5 gün (Vehicle alanı + migration + Supabase table + web page + sharing UI + view tracking).

---

## 4. 📊 CSV/PDF Veri Export (veri sahipliği)

**Problem:** Kullanıcı 3 yıllık masraf verisi biriktirdi. Uygulama dışında kullanmak istiyor (Excel'de analiz, vergi dosyası, başka app). Şu an sadece PDF var, o da satış dosyası formatında — genel export yok.

**Çözüm:** Ayarlar → "Verileri Dışa Aktar". İki format:
- **CSV:** Tüm masraflar (tarih, kategori, tutar, km, satıcı, not), bakım kayıtları, hatırlatıcılar. UTF-8 BOM ile (Excel TR desteği).
- **PDF (Genişletilmiş):** Yıllık raporun farklı formatları — Kategori özet tablosu, aylık trend, kilometre-bazlı analiz.

**UI/UX:** Ayarlar → "Verilerim" bölümüne yeni satır. Tıkla → alt menü: "Masraflar (CSV)", "Bakımlar (CSV)", "Tümü (PDF)". ShareSheet ile dışa aktar.

**Teknik:**
- `Services/DataExportService.swift` — yeni service
- CSV: string formatlama, `;` ayraç (TR locale) veya `,`
- PDF: mevcut `PDFExportService`'i extend et veya yeni `ComprehensiveReportPDFService`
- Dosya oluştur → `UIActivityViewController` ile paylaş

**Fayda:** "Verilerim benim" hissi — kullanıcı app'ten bağımsız hissetmez, ama kontrol onda. Vergi için kritik. **Aylık aktif kullanım değil, yılda 1-2 kez yüksek değer.**

**Pro değeri:** ⭐⭐⭐ Orta — yüksek değer ama düşük sıklık. Mevcut Free'de satış PDF'i var, Pro'ya yeni katma değer.

**Efor:** 1-2 gün (CSV writer + PDF template + share sheet).

---

## 5. 📱 Home Screen Widget

**Problem:** Kullanıcı her seferinde app'i açıp "bugün ne yapmam lazım" diye bakıyor. Sık kullanıcılar için friction.

**Çözüm:** 2 widget:
- **Küçük (2x2):** Bir sonraki reminder (varsa) + plaka + gün sayısı. "Muayene • 12 gün". Yoksa "Tüm işler tamam ✓".
- **Orta (4x2):** İlk 2 reminder + aktif araç sayısı + bu ay masraf.

**UI/UX:** iOS Standart widget tasarımı (SF Pro). Dark/light mode otomatik. Pro badge sağ altta küçük (mevcut token sistemi). Widget galerisinde "Arvia Pro Widget" adı.

**Teknik:**
- `WidgetExtension/` — yeni app extension target (project.pbxproj ekleme gerekir)
- `AppGroup` ile data paylaşımı (UserDefaults veya dosya)
- Timeline provider: her saat güncelle, kritik reminder varsa daha sık
- `WidgetCenter.shared.reloadAllTimelines()` — app'te veri değişince trigger

**Fayda:** App'i açmadan bilgi → retention artışı, sık kullanıcı. **Widget tıklanınca app'te ilgili reminder'a yönlendir.**

**Pro değeri:** ⭐⭐⭐ Orta — bireysel kullanıcı için retention değeri yüksek, ama teknik setup ağır (extension target, App Group provisioning).

**Efor:** 3-4 gün (extension setup + App Group + timeline logic + provisioning). Projenin yapısı gereği yeni target eklemek maliyetli.

---

## 6. 💱 Çoklu Para Birimi (tatil/yurt dışı)

**Problem:** Kullanıcı yurt dışına gitti, EUR cinsinden yakıt aldı, otopark ödedi. Uygulama sadece TL. Manuel çevirme zahmetli.

**Çözüm:** Masraf eklerken para birimi seçimi (TRY, EUR, USD, GBP). Görüntüleme daima TRY (kullanıcının tercih ettiği). Geçmiş çeviri kuru kaydedilir (o günkü kur) — daha sonra kur değişirse tutar değişmez, doğru vergi kaydı.

**UI/UX:** Masraf formunda "₺" simgesi yerine dropdown (TRY/EUR/USD/GBP). Seçilince otomatik TRY karşılığı hesaplanır ve gösterilir: "€50 → ₺1.750 (kur: 35,00)". Geçmiş ekranda orijinal birim de görünür: "₺1.750 (€50)".

**Teknik:**
- `Expense.currency: String` (ISO 4217) — yeni alan, default "TRY", SwiftData migration
- `Expense.exchangeRate: Double?` — kayıt anındaki kur, default nil
- `Services/CurrencyService.swift` — kur cache (günlük), `exchangerate-api.com` veya `TCMB` (ücretsiz, basit)
- `ReportsView` ve `Summary`'de toplamlar TRY cinsinden (tutarlı)

**Fayda:** Niş ama gerçek — yılda 1-2 kez yurt dışına giden Türk kullanıcı için somut değer. **Vergi/döviz hesabı kolaylaşır.**

**Pro değeri:** ⭐⭐⭐ Orta — küçük ama sadık kitle, "beni düşünmüşler" hissi.

**Efor:** 2-3 gün (currency service + form değişikliği + migration + reports toplamları).

---

## Özet Tablo

| # | Öneri | Pro Değeri | Efor | Somutluk |
|---|---|---|---|---|
| 1 | 🧠 Akıllı Hatırlatıcı (km pattern) | ⭐⭐⭐⭐⭐ | 1-2 gün | Yüksek |
| 2 | 📈 Yıllık Derin Rapor | ⭐⭐⭐⭐ | 3-4 gün | Yüksek |
| 3 | 🔗 Sınırlı Süreli Satış Linki | ⭐⭐⭐⭐ | 4-5 gün | Çok yüksek |
| 4 | 📊 CSV/PDF Export | ⭐⭐⭐ | 1-2 gün | Yüksek |
| 5 | 📱 Home Screen Widget | ⭐⭐⭐ | 3-4 gün | Orta |
| 6 | 💱 Çoklu Para Birimi | ⭐⭐⭐ | 2-3 gün | Niş ama gerçek |

---

## Önerilen Sıralama (kullanıcı verisi gelene kadar)

1. **#1 Akıllı Hatırlatıcı** — en hızlı ROI, mevcut rehberi uzatır
2. **#4 CSV/PDF Export** — düşük efor, yüksek değer
3. **#6 Çoklu Para Birimi** — küçük kitle için fark yaratır
4. **#2 Yıllık Rapor** — yeni ekran + chart'lar
5. **#3 Satış Linki** — Faz 4.2 ile çakışıyor (usta QR), ama sadece okuma amaçlı, daha erken yapılabilir
6. **#5 Widget** — teknik setup ağır, sona kalmalı

---

## Açık Sorular

- Hangi 1-2 öneriyi önce yapalım?
- Kullanıcı geri bildirimi geldikçe sıralama değişebilir mi?
- #3 Satış Linki için Faz 4.2 (Usta) ile ortak QR altyapısı kurulabilir mi?
- #5 Widget için bütçe var mı (extension target setup + App Group provisioning)?