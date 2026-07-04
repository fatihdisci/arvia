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

## Açık Sorular

### #1 Akıllı Sürüş Asistanı

**A. Tanışma Akışı (Katman A — kullanıcı profili)**

1. **Tanışma akışı ne zaman gösterilsin?**
   - (a) Pro'ya geçtiği anda (zaten ödeme yaptı, motivasyonu yüksek)
   - (b) İlk araç eklediğinde (aracı bağlamadan kullanıcı neyi kullanacağını bilmiyor olabilir)
   - (c) Pro aktifken ayarlardan tetikle (opsiyonel, hiç sorma)

2. **Sorular zorunlu mu, yoksa "atla" seçeneği olsun mu?**
   - Profil eksikse tahmin motoru düşük güvenle çalışır (az veri → jenerik öneri). Tüm soruları zorunlu tutmak mı yoksa "sonra doldururum" demek mi?

3. **Profil araç başına mı yoksa kullanıcı başına mı?**
   - (a) Her araç için ayrı profil (farklı araçlar farklı kullanım olabilir — ev arabası vs. iş arabası)
   - (b) Tek profil tüm araçlara uygulanır
   - (c) Varsayılan: araç başına, ama global profil de ayarlardan seçilebilir

**B. Tahmin Motoru (Katman B)**

4. **Veri azken ne yapacak?**
   - (a) Hiç insight göstermez ("daha fazla veri lazım" mesajı)
   - (b) Rule-based jenerik öneri gösterir (kullanıcı profili olmadan)
   - (c) Profilden gelen cevaplara göre başlangıç tahmini üretir

5. **Tahmini km güncelleme sıklığı ne olsun?**
   - (a) 30 günden eski ise sor
   - (b) 60 günden eski ise sor
   - (c) Kullanıcı ayarlardan eşik seçsin (7/30/60/90 gün)

**C. Proaktif Etkileşim (Katman C)**

6. **Insight'lar Bildirim olarak da gitsin mi?**
   - (a) Sadece uygulama içi (Garaj → Bugün Garajında)
   - (b) Push bildirim (kritik insight'lar için: "30 gündür km güncellemedin")
   - (c) Kullanıcı ayarlardan seçsin

7. **"Bu doğru mu / Güncelle" onay mekanizması nasıl çalışsın?**
   - (a) Dokun → doğrudan km input ekranı açılır
   - (b) Tahmini kabul edince "şu an ~52.400 km" olarak kaydedilir (manuel girmek zorunda değil)
   - (c) Sadece tahmini kabul et / reddet butonu, kabul edince onay olarak işaretlenir ama kayıt değişmez

8. **AI katmanı (gelecek): Hangi LLM?** (Şimdilik planlaması bile yeterli)
   - (a) OpenAI GPT-4o mini (maliyet orta, kalite yüksek)
   - (b) Anthropic Claude Haiku (kaliteli, maliyet benzer)
   - (c) On-device (Apple Intelligence, sadece iOS 18+)
   - (d) Şimdilik düşünme, rule-based ile başla

---

### #2 OCR + AI Fatura Tarama

**A. Akış ve Tetikleme**

9. **"Fiş Tara" butonu nereye koyalım?**
   - (a) Masraf ekleme ekranında, "Manuel Ekle" butonunun yanında
   - (b) Bakım ekleme ekranında
   - (c) Hem masraf hem bakımda + Garage ana sayfada kısayol
   - (d) Floating Action Button (FAB) — her yerden erişim

10. **Çoklu fotoğraf desteği nasıl olsun?**
    - (a) Sadece tek fotoğraf (basit)
    - (b) Çoklu fotoğraf → her birini ayrı parse et, sonra birleştir veya kullanıcı seçsin
    - (c) Çoklu fotoğraf → tek bir belge olarak birleştirilir (2 sayfa fatura)

11. **Sonuç ekranı: kullanıcı ne görecek?**
    - (a) Parse edilmiş alanlar (tarih, tutar, kategori, KM, satıcı) otomatik dolu — kullanıcı sadece onaylar
    - (b) Alanlar dolu + kullanıcı düzeltebilir (bugünkü masraf formuna benzer)
    - (c) Yan yana: sol tarafta fotoğraf, sağ tarafta form

**B. Akıllı Yönlendirme**

12. **Masraf mı Bakım mı otomatik mi anlasın?**
    - (a) LLM/rule-based otomatik karar verir
    - (b) Kullanıcı toggle ile seçer ("Bu bir bakım faturası mı?")
    - (c) OCR sonucu belirsizse sorar, net ise otomatik yapar

13. **Kategori otomatik mi önerilsin?**
    - (a) Anahtar kelime bazlı (YAKIT → yakıt, MOTOR YAĞI → bakım)
    - (b) Kullanıcı seçer
    - (c) LLM önerir + kullanıcı onaylar

**C. LLM ve Maliyet**

14. **LLM hangi durumda tetiklensin?**
    - (a) Sadece yerel Vision yeterli mi yoksa karmaşık faturalar için LLM mi?
    - (b) Her zaman LLM (en doğru sonuç, en yüksek maliyet)
    - (c) Kullanıcı ayarlardan seçsin (yerel / bulut / otomatik)
    - (d) İlk başta sadece yerel, LLM'i sonra ekleriz

15. **LLM maliyeti modeli?**
    - (a) Pro abonelik fiyatına dahil (sen karşılarsın)
    - (b) Kullanıcı kendi API key'ini girer
    - (c) Kullanıcı başına aylık kota (örn. ayda 50 tarama ücretsiz, sonrası küçük ücret)
    - (d) Şimdilik planlama — sadece yerel Vision

**D. Veri ve Saklama**

16. **Taranan orijinal görsel nerede saklansın?**
    - (a) Sadece cihazda (SwiftData local)
    - (b) Supabase'e yedekle (kullanıcı hesabı varsa)
    - (c) Belge kasasına otomatik eklenir (mevcut yapı)
    - (d) Kullanıcı seçsin: sadece cihaz / bulut / her ikisi

17. **"Receipt" ayrı model mi yoksa Expense'e mi gömülü?**
    - (a) Ayrı Receipt modeli (imageData + ocrText + parsedFields), Expense'e bağlı (linkedExpenseId)
    - (b) Expense modeline imageData + rawOCRText alanları ekle (tek model, basit)
    - (c) Hibrit: ham OCR text Expense'te, orijinal görsel Receipt modelinde