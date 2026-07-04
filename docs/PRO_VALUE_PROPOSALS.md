# Arvia Pro — Değer Önerileri Backlog Raporu

> **Tarih:** 4 Temmuz 2026
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

**Gözlem:** Pro değerinin büyük kısmı "kaç araç" ekseninde. **Veri derinliği/analizi eksik** — kullanıcı 5 yıl masraf topladığında uygulama ona "şu öneriyi yaparım" demiyor. Bu açığı kapatacak aşağıdaki 2 öneri odak backlog'u oluşturur; diğer fikirler (widget, çoklu para birimi, CSV export, satış linki, yıllık rapor) elendi — efektif bulunmadı.

---

## 1. 🤖 Akıllı Sürüş Asistanı

**Problem:** Uygulama bugün kullanıcıyı dinlemez — sadece ne girdiyse onu gösterir. Oysa kullanıcı km güncellemeyi unutuyor, alışkanlıkları bilinmiyor, bakım önerileri jenerik (kullanım tipine göre değil). "Bu app beni tanımıyor" hissi.

**Çözüm:** Üç katmanlı akıllı asistan — kullanıcıyı dinleyen, geçmişten öğrenen, proaktif öneri üreten yapı.

### Katman A — Alışkanlık Profili (kullanıcı girdisi)

İlk kullanımda veya Pro'ya geçiş sonrası kısa "tanışma" akışı:
- Günde ortalama kaç km yaparsın? (slider/segment: <20, 20-50, 50-100, 100+)
- Genelde şehir içi mi, şehir dışı mı, karma mı?
- Yakıt tüketimini biliyor musun? (opsiyonel sayısal giriş — şehir içi / dışı)
- Aracı genelde kim kullanıyor?
- Tipik yolculuk türün? (işe gidiş, tatil, hafta sonu vs. — çoklu seçim)

Bu cevaplar `VehicleUsageProfile` modeline kaydedilir. Sonradan ayarlardan düzenlenebilir.

### Katman B — Tahmin Motoru (veri girdikçe)

Kullanıcının son 3-6 aydaki masraf ve km kayıtlarından gerçek kullanım profili çıkarılır:
- **Tahmini günlük km:** Son 90 gündeki masrafların km farklarından ortalama
- **Tahmini tüketim:** Yakıt masrafları + km farklarından L/100km
- **Yol tipi dağılımı:** Km değişim hızına göre (ani yükselişler = uzun yol)

### Katman C — Proaktif Etkileşim

**A) Tahmini km sorgulaması:** Kullanıcı 30+ gündür km güncellemediyse Garaj → Bugün Garajında'da yeni insight:
> "Aracının şu an yaklaşık **52.400 km** olmalı. Bu doğru mu?"
> [Doğru, devam et] [Güncelle]

**B) Bakım önerisi adaptasyonu:** Kullanıcının yol tipi ve km ortalamasına göre:
- "Senin aracın ortalama 47 km/gün yapıyor. Triger 90.000 km'de — senin kullanımınla bu 5.5 yıl sonra."
- Şehir dışı ağırlıklıysa motor yağı değişim sıklığı farklı önerilir
- Elektrikli araçta batarya sağlığı takibi öne çıkar

**C) Mevsimsel + alışkanlık kombine tahmin:** "Temmuz'da 2.500 km'ye ulaşabilirsin, yaz öncesi klima kontrolü eklemeyi düşün."

### AI opsiyonu (sonraya)

İlk aşamada **AI olmadan** çalışır (rule-based + ortalama). İleride:
- Masraf açıklamalarından NLP ile yol tipi çıkarma
- LLM ile kişiselleştirilmiş bakım planı
- Kullanıcının ses tonuyla konuşan mini-asistan

**UI/UX:**
- **Onboarding sonrası (Pro'ya geçiş):** 4-5 soruluk tanışma akışı (slider/segment ağırlıklı, her biri 1 ekran)
- **Garaj → Bugün Garajında:** Yeni insight tipi `.predictiveAssistance` (`brain.head.profile`)
- **Ayarlar → "Kullanım Profilim":** Düzenleme ekranı

**Teknik:**
- `Models/VehicleUsageProfile.swift` — yeni SwiftData modeli (vehicleId, dailyKmAverage, routeType, fuelConsumptionCity, fuelConsumptionHighway, primaryUser, tripTypes, updatedAt)
- `Services/UsageProfileService.swift` — onboarding'den tetiklenir, ayarlardan güncellenebilir
- `Services/PredictiveOdometerService.swift` — son masraf/km kayıtlarından tahmin
- `Services/MaintenanceAdvisorService.swift` — kullanım profili + araç tipi → kişiselleştirilmiş bakım önerileri
- Yeni `VehicleInsightType.predictiveAssistance` + `predictiveMaintenance` enum case'leri
- Faz 1.1 rehberiyle entegre (VehicleInsightCard)

**Pro değeri:** ⭐⭐⭐⭐⭐ En yüksek — uygulamayı "araç yönetim aracı"ndan "kişisel araç asistanına" taşır.

**Efor:** 5-7 gün
- 1 gün: VehicleUsageProfile modeli + SwiftData migration
- 1-2 gün: Onboarding tanışma akışı
- 1-2 gün: PredictiveOdometerService + insight entegrasyonu
- 2-3 gün: MaintenanceAdvisorService

---

## 2. 📸 OCR + AI ile Fatura Tarama

**Problem:** Kullanıcı benzin istasyonunda fiş alıyor, yağ değişiminde fatura geliyor, servis raporları PDF. Hepsini manuel girmek zahmetli — tarih, tutar, kategori, KM, satıcı. Pro kullanıcı için friction; kayıt tutma alışkanlığını kıran tek şey bu.

**Çözüm:** Fotoğraf veya PDF yükle → OCR → alanları parse et → kullanıcıya onay ekranı → kaydet. Süreç 3-5 saniye. İki katman:
- **Yerel (Vision + rule-based):** Ücretsiz, çevrimdışı, basit fişlerde iyi
- **Bulut (LLM ile, opsiyonel):** Karmaşık belgeler, çok satırlı bakım faturaları için daha doğru

**UI/UX:**
- Masraf ekle ve Bakım ekranlarında yeni buton: **"📸 Fiş/Fatura Tara"**
- Kamera veya galeriden seçim → çoklu fotoğraf destekli
- Yükleme sırasında skeleton + "Fiş okunuyor..." mesajı
- Sonuç ekranı: parse edilmiş alanlar form gibi — kullanıcı düzeltebilir
- "Bu bir bakım faturası" toggle'ı → bakım kaydına dönüşür (yoksa masraf)
- Ham görsel belge kasasına otomatik eklenir

**Teknik:**
- `Services/DocumentScannerService.swift` — VNDocumentCameraViewController entegrasyonu
- `Services/OCRService.swift` — VNRecognizeTextRequest (Türkçe dil paketi, iOS 16+)
- `Services/FaturaParserService.swift` — rule-based (regex: TUTAR, TARİH, KDV, TOPLAM, T.C.) + opsiyonel LLM
- `Features/Expenses/ReceiptScanView.swift` — capture + review ekranı
- `Models/Receipt.swift` — yeni SwiftData modeli (imageData, rawOCRText, parsedFields JSON)
- Privacy: LLM'e gönderilmeden önce kullanıcı onayı + maskeleme (TC, plaka)

**Pro değeri:** ⭐⭐⭐⭐⭐ En yüksek — somut zaman tasarrufu, haftalık/aylık kullanım. Diğer Pro özellikleri yılda 1-2 kez değerli iken bu haftalık.

**Efor:** 4-6 gün
- 1 gün: DocumentScannerService + OCR (yerel Vision) + Türkçe dil paketi
- 1-2 gün: FaturaParserService (rule-based + test)
- 1 gün: ReceiptScanView UI + form integration + belge kasası bağlantısı
- 1-2 gün: LLM entegrasyonu (opsiyonel)

---

## Özet Tablo

| # | Öneri | Pro Değeri | Efor | Somutluk |
|---|---|---|---|---|
| 1 | 🤖 **Akıllı Sürüş Asistanı** | ⭐⭐⭐⭐⭐ | 5-7 gün | Çok yüksek — katman özellik |
| 2 | 📸 **OCR + AI Fatura Tarama** | ⭐⭐⭐⭐⭐ | 4-6 gün | Çok yüksek — haftalık/aylık kullanım |

---

## Açık Sorular (varsayılan cevaplarla — kullanıcı onayına açık)

> Varsayımlar işaretli: **✓ KABUL** = benim önerim (değiştirilebilir). **[SEN]** = senin cevaplayacağın kritik karar.

### #1 Akıllı Sürüş Asistanı

**A. Tanışma Akışı (Katman A — kullanıcı profili)**

1. **Tanışma akışı ne zaman gösterilsin?**
   - ✓ KABUL: **(a) Pro'ya geçtiği anda** — motivasyon en yüksek an, "şimdi kişiselleştirelim" hissi. 4-5 soru, 90 saniyede biter.
   - Alt akış: Pro aktifleşince `OnboardingCoordinator` `UsageProfileOnboardingView`'i sunar → bitince `VehicleUsageProfile` kaydedilir → ana sayfaya döner.

2. **Sorular zorunlu mu?**
   - ✓ KABUL: **Zorunlu + "atla" seçeneği** — varsayılan cevaplarla başla, kullanıcı sonra düzenleyebilir. "Şimdi doldurmak istemiyorum" → tüm soruları orta değerle kaydet, sonradan ayarlardan değiştir.

3. **Profil araç başına mı?**
   - ✓ KABUL: **(a) Her araç için ayrı profil** — gerçek hayatta ev arabası vs. iş arabası farklı kullanım. Global profil yok (karmaşıklığı azaltır). SwiftData: `VehicleUsageProfile.vehicleId` foreign key.

**B. Tahmin Motoru (Katman B)**

4. **Veri azken ne yapacak?**
   - ✓ KABUL: **(c) Profil cevaplarına göre başlangıç tahmini üretir** — veri 0 olsa bile profil (günde 50 km + şehir içi) → "Tahmini şu anki km: 67.500" üretir, düşük güven badge'i ile gösterir. Veri arttıkça badge kaybolur.
   - Uygulama: `PredictiveOdometerService.confidence: .low | .medium | .high` enum.

5. **Tahmini km güncelleme eşiği:**
   - ✓ KABUL: **(c) Kullanıcı ayarlardan seçsin** — varsayılan 30 gün. Ayarlar → Predictive Insights → "Hatırlatma eşiği: [7/30/60/90 gün]".

**C. Proaktif Etkileşim (Katman C)**

6. **Insight'lar push bildirim olarak da gitsin mi?**
   - ✓ KABUL: **(c) Kullanıcı ayarlardan seçsin** — varsayılan kapalı. "Kritik" insight'lar (örn. 90+ gün km güncellemedi) için bildirim izni istenir. Ayarlar → Predictive Insights → "Push bildirim: açık/kapalı".

7. **Onay mekanizması:**
   - ✓ KABUL: **(b) Tahmini kabul edince doğrudan kaydedilir** — "Doğru, devam et" → odometer update olarak kaydedilir (tarih + km + kaynak: `predicted`). Geçmiş km kayıtlarında `source: .user | .predicted` ayrımı → PredictiveMaintenanceService sadece `.user` kayıtlardan öğrenir (kendi tahminini kendine referans almaz).

8. **AI katmanı (gelecek):**
   - ✓ KABUL: **(d) Şimdilik rule-based başla**, sonra LLM ekle. İlk sürüm tamamen yerel. Faz 2: kullanıcı kendi API key'i (OpenAI veya Anthropic) girerse LLM opsiyonel olarak devreye girer.

---

### #2 OCR + AI Fatura Tarama

**A. Akış ve Tetikleme**

9. **"Fiş Tara" butonu nereye?**
   - ✓ KABUL: **(c) Hem masraf hem bakımda + Garage ana sayfada kısayol** — masraf eklemek için ana akış (fişler çoğunlukla masraf), bakım için de (faturalar), Garage'da hızlı erişim. FAB yok (tasarım anayasasına aykırı, iOS native his).

10. **Çoklu fotoğraf desteği:**
    - ✓ KABUL: **(a) Sadece tek fotoğraf (v1)** — basit, %90 fiş tek sayfa. Çoklu foto ihtiyacı gerçek ama MVP'de atlıyoruz. Faz 2: çoklu foto desteği (her biri ayrı parse, kullanıcı en iyisini seçer).

11. **Sonuç ekranı:**
    - ✓ KABUL: **(b) Alanlar dolu + kullanıcı düzeltebilir** — bugünkü masraf formuna benzer ekran. Trust modeli: kullanıcı her zaman görür ve düzeltebilir, "otomatik kaydet" yok. Tasarım: üstte küçük fotoğraf önizleme (tap → büyüt), altta form alanları (tarih, tutar, kategori, KM, satıcı, not).

**B. Akıllı Yönlendirme**

12. **Masraf mı Bakım mı otomatik mi?**
   - ✓ KABUL: **(c) Belirsizse sor, net ise otomatik** — rule-based tetikleyici: "SERVİS", "BAKIM", "YAĞ DEĞİŞİMİ", "TRİGER" kelimeleri geçiyorsa → bakım. Sadece tutar + tarih varsa → masraf. Belirsiz ise ("OPET", "SHELL" gibi sadece marka) → kullanıcıya sor.

13. **Kategori otomatik mi?**
   - ✓ KABUL: **(a) Anahtar kelime bazlı** — `CategoryClassifier` regex/sözlük: YAKIT/MOTORİN/BENZİN/LPG → yakıt; MOTOR YAĞI/FİLTRE/FREN → bakım; OTOPARK/OTOYOL → ulaşım. Belirsiz ise kullanıcı seçer. LLM yok (v1).

**C. LLM ve Maliyet**

14. **LLM hangi durumda tetiklensin?**
   - ✓ KABUL: **(d) v1 sadece yerel Vision** — Vision framework yeterli (Türkçe dil paketi dahili). Rule-based parser ile %80 doğruluk hedefi. LLM v2'de: belirsiz sonuç + kullanıcı onayı alırsa buluta gönder.

15. **LLM maliyeti modeli:**
   - ✓ KABUL: **(d) Şimdilik planlama yok** — v1 tamamen yerel Vision, maliyet 0. v2 LLM gelince bu soru tekrar açılır (büyük ihtimalle kullanıcı kendi API key'i + aylık kota).

**D. Veri ve Saklama**

16. **Taranan orijinal görsel nerede?**
   - ✓ KABUL: **(c) Belge kasasına otomatik eklenir** — mevcut `BelgeKasası` yapısıyla entegre. Kullanıcı Pro olmasa bile fiş tarayabilir (belge kasası Free'de zaten var), ama OCR + parse Pro özelliği. SwiftData'da yerel + opsiyonel Supabase yedek (mevcut belge kasası mantığı).

17. **"Receipt" ayrı model mi?**
   - ✓ KABUL: **(a) Ayrı Receipt modeli** — temiz mimari, Expense ve ServiceRecord'un ikisine de bağlanabilir. SwiftData: `Receipt.id, imageData, rawOCRText, parsedFields (JSON), linkedExpenseId?, linkedServiceRecordId?, createdAt`. Expense modeline `receiptId` (opsiyonel), ServiceRecord'a `receiptId` (opsiyonel).