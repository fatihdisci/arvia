# Arvia — Yol Haritası ve Stratejik Kararlar

> **Tarih:** 3 Temmuz 2026 (son güncelleme: paywall review-safe redesign)
> **Hazırlayan:** Fatih + Mavis
> **Referans:** `00_README.md` (genel bakış), `01_DESIGN.md` (tasarım anayasası), `02_PRODUCT_SCOPE.md` (feature haritası), `docs/RESEARCH_ARVIA_GUIDE_SCENARIOS.md` (Gemini raporu)
>
> Bu dosya, MVP sonrası ve v1.1+ güncellemelerinde uygulanacak **stratejik kararları** ve **yol haritasını** tek noktada toplar. Yeni geliştirici/agent bu dosyayı + `01_DESIGN.md` + ilgili prompt dosyasını okuyarak bağlamı kapar.

---

## DURUM ÖZETİ (3 Temmuz 2026)

| Faz | İş | Durum |
|---|---|---|
| Faz 0 | TestFlight Internal Testing | ✅ Tamamlandı |
| Faz 1.1 | Arvia Rehber 5 içerik tipi (CTA/Bilgi/Uyarı/Hatırlatma/Soru) | ✅ Tamamlandı |
| Faz 1.2 | Açık mod border + subtle fill (artık dark-only) | ✅ Tamamlandı (irrelevant) |
| Faz 1.3 | Hero kart köşe bokluğu | ✅ Tamamlandı |
| Faz 2.1 | Dosya Skoru → Garaj hero altı (Karar 3.1) | ✅ Tamamlandı |
| Faz 2.2 | MilestoneCard (yaşam çizgisi, Karar 3.3) | ✅ Tamamlandı |
| Faz 2.3 | DemoDataSeeder 5 senaryo (Karar 3.4) | ✅ Tamamlandı |
| Faz 2.4 | 3 adım wizard (Karar 3.5) | ✅ Tamamlandı (yeni VehicleWizardView) |
| Faz 2.5 | Satış dosyası PDF branding (Karar 3.6) | ✅ Tamamlandı |
| Faz 2.6 | Onboarding sonrası rehber tanıtım banner | ✅ Tamamlandı |
| Faz 3.1 | Pro stratejisi (1 araç limit, lifetime korunur) | ✅ Korunuyor |
| Faz 3.2 | Gelecek Pro değerleri (7 backlog) | ⏳ Backlog — kullanıcı verisi bekleniyor |
| Faz 4.1 | iCloud/CloudKit sync | ⏸ Ertelenmiş (altyapı hazır, kapalı) |
| Faz 4.2 | Usta/Servis Paneli (ayrı app target) | ⏸ Ertelenmiş (~23-31 gün) |
| Faz 4.3 | Hesap silme + Supabase temizlik | ⏸ Manuel test gerekli |
| Paywall | Apple review-safe redesign (scroll'suz, tek detent) | ✅ Tamamlandı |

**Mevcut commit'ler (bu sprint):**
```
a4491e8 fix(paywall): sheet detent medium → fraction 0.65
5799e38 fix(paywall): swipe kapatıldı — tek detent, drag indicator gizli
efba03f fix(paywall): sheet detent medium ile başlasın
3c6d90d fix(paywall): Apple review uyumlu kompakt tasarım
1ef0d31 feat(rehber): Faz 2.6 onboarding sonrası rehber tanıtım banner'ı
0433da0 feat(wizard): 3 adımlı araç ekleme wizard'ı (Karar 3.5)
ba8efb3 polish(milestone): VehicleDetailMilestoneCard dark luxury tasarıma uyarlandı
20aa37d feat(garage): Dosya Skoru kartı hero altında gösterildi (Karar 3.1)
597f6e5 polish(guide): Faz 1.1 insight metinleri Gemini tonuna yumuşatıldı
8522a09 fix(icon): AppIcon 1024x1024 boyut düzeltmesi
```

**Sıradaki:** TestFlight'e build gönderilebilir (Faz 1+2 feature'ları tamam). Backlog Pro değerleri kullanıcı verisi geldikçe planlanır.

---

## Nasıl kullanılır

1. **Yeni code agent başlatırken:** Bu dosyayı + `01_DESIGN.md` + ilgili prompt dosyasını okut.
2. **PR review'da:** PR açıklamasında bu yol haritasından referans ver ("Karar 4.2 gereği..." gibi).
3. **Ürün tartışmasında:** Karar değişirse bu dosyada değiştir, commit'le. Bu dosya canlı dokümandır.
4. **Yeni geliştirici katılırsa:** İlk okuduğu dosya bu olsun.

---

## YOL HARİTASI — Öncelik Sırası

> **Öncelik prensibi:** Gemini raporundaki içerik tasarım stratejisi + UI/UX polish → içerik/iş mantığı işleri → **en sonda** usta tarafı ve altyapı entegrasyonları (zor işler).

### Faz 0 — TestFlight Internal Testing (TAMAMLANDI ✅)

Hero köşe bokluğu, açık mod border, MTV bug fix'leri, manifestoya Karar 4.1+4.2 kayıtları. Commit'ler: `ee78bee`, `dda6539`, `2b135ca`. Build: 151/151 test geçti.

---

### Faz 1 — İçerik Tasarımı ve UI/UX Polish (ÖNE ALINDI) 🔥 ✅ TAMAMLANDI

**Hedef:** Gemini raporundaki "Arvia Rehber içerik stratejisi"ni uygulamaya entegre et. Tasarım anayasasıyla (Settings.app hissi, AI-slop yasak) uyumlu, kullanıcıyı eyleme zorlamayan bilgi kartları.

#### 1.1 Arvia Rehber — CTA-zorunlu yapıdan 5 içerik tipine dönüşüm (Karar 4.2) — TAMAMLANDI ✅

**Sorun:** Mevcut 13 rehber kartının hepsi CTA-zorunlu → kullanıcı "robotik" ve "eyleme zorlayan bildirim paneli" algısı oluşuyor, kartları göz ardı ediyor.

**Çözüm:** 5 içerik tipi kategorisi + opsiyonel action + dismiss mekanizması.

| Tip | Priority | Tetikleyici | Etkileşim | Snooze |
|---|---|---|---|---|
| **A. CTA (Eylem)** | .important | Yasal gecikmeler (TÜVTÜRK, MTV), kritik eksik belgeler | Zorunlu birincil buton | Yok / 3 gün |
| **B. Bilgi** | .info | Mevsim geçişleri, yakıt tipi önerileri, batarya sağlığı | "Anlaşıldı" dismiss | 90 gün (sezon) |
| **C. Uyarı** | .warning | Ağır bakım eşikleri (DSG 60K, CVT 40K), yüksek km | Geçmiş ekranı + "Anlaşıldı" | 14-30 gün |
| **D. Hatırlatma (Pasif)** | .info | MTV taksit dönemleri, sahiplik yıl dönümü | "Anlaşıldı" | Olay sonuna kadar |
| **E. Soru (Yumuşak)** | .info | Uzun süredir veri girilmemiş, belirsiz km | "Ekle" + "Şimdi Değil" | 30 gün |

**Mevcut 13 insight → yeni tip eşlemesi:**

| Eski Tip | Yeni Tip | Yeni CTA / Dismiss | Snooze |
|---|---|---|---|
| `overdueReminder` | A. CTA | openTodos (zorunlu) | Yok |
| `upcomingReminder` | C. Uyarı | addReminder veya Dismiss | 14 gün |
| `calendarPeriod` | D. Hatırlatma | addMTVReminder veya Dismiss | Dönem sonu |
| `odometerUpdate` | E. Soru | updateOdometer veya "Şimdi Değil" | 30 gün |
| `seasonalGuidance` | B. Bilgi | Dismiss | 90 gün |
| `fuelTypeGuidance` | B. Bilgi | Dismiss | 60 gün |
| `transmissionGuidance` | C. Uyarı | addServiceRecord veya Dismiss | 30 gün |
| `odometerMilestone` | B. Bilgi | Dismiss | Kalıcı |
| `monthlyExpensePrompt` | E. Soru | addExpense veya "Şimdi Değil" | 30 gün |
| `maintenance` | C. Uyarı | addServiceRecord veya Dismiss | 14 gün |
| `missingDocument` | A. CTA | addDocument (zorunlu) | Yok |
| `quietGoodState` | D. Hatırlatma | Dismiss | 7 gün |
| `saleFileReadiness` | B. Bilgi | openSaleFile veya Dismiss | 30 gün |

**Swift mimari değişiklikleri:**

1. `VehicleInsight.action` → opsiyonel (`VehicleInsightAction?`). `nil` = CTA yok.
2. Yeni enum `VehicleInsightContentKind`: `.callToAction / .info / .warning / .reminder / .softQuestion`
3. Yeni `VehicleInsightAction` case'leri: `.dismissAndSnooze`, `.markAsRead`, `.acknowledge`, `.noAction`
4. `InsightSnoozeStore` → UserDefaults tabanlı, `snooze(insightType:forVehicle:days:)` API'si, anahtar formatı `com.arvia.snooze.{vehicleId}.{insightType}`. Mevcut store bu yapıya genişletilecek (şu an sadece `.calendarPeriod` için var).
5. Yeni component `VehicleInsightCard` — dismiss butonu (`.callToAction` dışındaki tüm tipler için) + soru tipi için çift buton yapısı.
6. SwiftData migration: zorunlu `action` → opsiyonel `action` + yeni `contentKind` alanı. Veri kaybı olmamalı.
7. 13 mevcut kartın metni **Gemini raporundaki ton kurallarına** göre yeniden yazılacak.

**Ton ve üslup kuralları (Gemini raporundan):**

1. Edilgen ve yardımcı fiillerle yumuşatma — "yap/et/gir/yükle" yok; "faydalı olabilir / işini kolaylaştırır / tercih edebilirsin".
2. Gerekçe gösterme — veri girişi isteniyorsa faydası açıklanmalı.
3. Teknik terim parantez içi açıklaması — DPF (Dizel Partikül Filtresi), SoH (Batarya Sağlık Oranı), MTV.
4. Karakter limitleri — başlık max 4-5 kelime (≤30 karakter), gövde max 2 cümle (≤120 karakter).
5. "Sen" dili ama mesafeli — "dostum" gibi AI-slop yasak, "bilge yol arkadaşı" tonu.

**Test stratejisi:** `DemoDataSeeder`'a 5 yeni senaryo eklenecek (Karar 3.4 genişletmesi):
- Kritik Eylem (TÜVTÜRK gecikmesi, 715 gün)
- Sezonluk Bilgi (BEV kış, %20-80 batarya)
- Mekanik Uyarı (DSG 60K filtre değişimi)
- Pasif Hatırlatma (MTV taksit dönemi)
- Yumuşak Soru (Aylık masraf prompt)

**Referans:** `docs/RESEARCH_ARVIA_GUIDE_SCENARIOS.md` (Gemini raporu, 670 satır, 39 kaynak).

**Tahmini süre:** 3-4 gün.

---

#### 1.2 Açık Mod: Border + Subtle Fill (Karar 4.1) — TAMAMLANDI ✅

Commit: `dda6539`. 151/151 test geçti, TestFlight internal testing'e gönderildi.

#### 1.3 Hero Card köşe bokluğu — TAMAMLANDI ✅

Commit: `2b135ca`. Hero iki ayrı karta bölündü (photo + info), gap ile temiz ayrım.

---

### Faz 2 — Ürün Genişletme (İÇERİK/TASARIM AĞIRLIKLI) ✅ TAMAMLANDI

#### 2.1 Dosya Skoru checklist'i Garaj'a taşı (Karar 3.1) — TAMAMLANDI ✅

`DosyaniTamamlaChecklist` component'i zaten var (Araç Detay'da gösteriliyor). Bunu **Garaj hero altına** da taşı.

**Skor hesaplama mantığı:**

| Kategori | Puan | Koşul |
|----------|------|-------|
| Temel bilgiler | 40 | plaka + marka + model + yıl + km + vites + motor (motosiklet) + satın alma tarihi |
| Araç fotoğrafı | 10 | `vehicle.photoFileName != nil` |
| Belgeler | 25 | En az 1 belge 15p, 3+ farklı belge tipi 10p (belge olmadan %100 olamaz) |
| Hatırlatıcı | 10 | En az 1 aktif reminder |
| Masraf | 8 | En az 1 expense |
| Bakım | 7 | En az 1 service record |
| **Toplam** | **100** | |

**Tahmini süre:** 2 saat.

#### 2.2 Araç Yaşam Çizgisi: signature element (Karar 3.3) — TAMAMLANDI ✅

Mevcut dikey liste korunur. Üzerine kritik milestone'lara ayrıcalıklı `MilestoneCard` eklenir.

**Kritik milestone kriterleri:**
1. Araç satın alma (`Vehicle.purchaseDate` set edilmişse)
2. İlk büyük bakım (parts_cost > 5000 TRY VEYA service_type = major)
3. Ekspertiz raporu
4. Satış dosyası oluşturulmuş
5. 5+ yıl sahiplik dönüm noktası

**Tahmini süre:** 1 gün.

#### 2.3 Insight test stratejisi — DemoDataSeeder (Karar 3.4) — TAMAMLANDI ✅

`DemoDataSeeder`'a 5 senaryo (Karar 1.1'deki 5 rehber senaryosuyla birleştirilebilir).

| Senaryo | Durum | Test amacı |
|---------|-------|------------|
| `.empty` | Hiç araç yok | Empty state, CTA, hata yok |
| `.singleReminder` | 1 araç, 1 reminder | Sakin state |
| `.overdueState` | 1 araç, 1 overdue reminder | Kırmızı, primary |
| `.busyState` | 1 araç, 5 reminder | Çakışan insight'lar |
| `.quietGood` | 1 araç, tüm reminders completed | Sessiz iyi hal |

Developer Settings UI'ında seçilebilir. DEBUG-only. Marketing material için de kullanılabilir.

**Tahmini süre:** 1 gün.

#### 2.4 Onboarding → Araç Ekle: 3 adım wizard (Karar 3.5) — TAMAMLANDI ✅

Mevcut 6-section'lı `VehicleFormView` yerine 3 adımlı wizard:

1. **Tanımla** (zorunlu) — araç türü, plaka, marka, model, yıl
2. **Durumu** (opsiyonel) — km, yakıt, vites, kullanım, fotoğraf
3. **Sıradaki işler** (opsiyonel) — 3 hazır buton (Muayene, Trafik Sigortası, MTV)

**Tahmini süre:** 3-4 gün.

#### 2.5 Satış dosyası PDF branding (Karar 3.6) — TAMAMLANDI ✅

PDF'e Arvia markası + App Store linki ekle. Kapak footer pill, son sayfa branding, içerik sayfalarına küçük footer.

**App Store URL placeholder** — submit sonrası gerçek URL ile değiştirilecek.

**Tahmini süre:** 30 dakika.

#### 2.6 Onboarding sonrası içerik tanıtımı — TAMAMLANDI ✅

Yeni kullanıcı ilk aracını ekledikten sonra Arvia Rehber'in ne işe yaradığını **pasif bir tooltip / banner** ile açıkla. CTA yok, sadece "Anlaşıldı" ile dismiss edilebilir. 7 gün snooze.

**Tahmini süre:** Yarım gün.

---

### Faz 3 — Pro Değerleri ve Monetizasyon Güçlendirme 🔄 KORUNUYOR / BACKLOG

#### 3.1 Pro stratejisi (Karar 3.2 — korunur) ✅

`PaywallService.FreeLimits.maxVehicles = 1`. 2+ araç = Pro.

**Apple Family Sharing devre dışı** (Karar 3.2.a) — Türkiye'de kullanım düşük.

**Lifetime ürünü şimdilik korunur** (Karar 3.2.b) — karar açık, conversion verisi gelince yeniden değerlendirilir.

#### 3.2 Gelecek Pro değerleri (backlog — sıralama veri gelince netleşir) ⏳

1. **Akıllı içgörüler (Insights Pro)** — pattern analizi ("Benzer kullanıcılar 50.000 km'de fren balatası değiştiriyor")
2. **Ekspertiz doğrulama rozeti** — TÜVTÜRK rapor doğrulama
3. **Sınırlı süreli satış dosyası linki** — public link, görüntülenme sayısı
4. **AI destekli hatırlatıcı önerisi** — kullanıcı verisinden pattern çıkarımı
5. **Partner entegrasyonu** — usta/expertiz indirimi (usta tarafıyla bağlantılı)
6. **Çoklu para birimi** — TL/Euro dönüşümü
7. **Beyaz etiket satıcı paketi (V2)** — galerici paketi

---

### Faz 4 — Altyapı ve Entegrasyon (ZOR İŞLER, SONA KALDI) ⏸ ERTELENMİŞ

> **Bu faz bağımsız başlamamalı.** Önce Faz 1 + Faz 2 tamamlanmalı, kullanıcı geri bildirimi alınmalı, sonra Faz 4'e geçilmeli.

#### 4.1 iCloud / CloudKit Sync ⏸ ERTELENMİŞ

Altyapı hazır, kapalı. Açma kararı kullanıcı verisi gelince.

- Xcode → Signing & Capabilities → + iCloud → CloudKit
- Container: `iCloud.com.ruhsatim.app`
- `AppEnvironment.isCloudKitSyncEnabled = true`
- Tüm SwiftData modelleri zaten CloudKit uyumlu

**Etki:** Apple girişi yapan kullanıcıların tüm verileri cihazlar arası senkronize olur.

#### 4.2 Usta / Servis Paneli — "Arvia Servis" (TODOS'tan) ⏸ ERTELENMİŞ

Ayrı app target. **Tahmini: 23-31 gün.** Detaylar aşağıda "USTA TARAFI" bölümünde.

#### 4.3 Hesap silme + Supabase temizlik ⏸ MANUEL TEST GEREKLİ

- Hesap silmenin Supabase tarafı manuel test edilecek
- Review'da hesap silme flow gerçekten çalışıyor mu doğrulanacak

---

## KARARLAR — Detaylı Açıklamalar

### 4.1 — Açık Mod: Border + Subtle Fill (TAMAMLANDI ✅)

**Karar (2 Temmuz 2026):** Açık modda beyaz zemin üstünde border'lar görünmez hale geldi — birçok card neredeyse hiç algılanmıyor. Önceki fix (`#D1D1D6 → #C7C7CC`) yetersiz kaldı. **3 seçenek tartışıldı:**

1. Sadece border koyulaştır — minimal ama yetersiz
2. **Border + Subtle Fill (kabul edilen)** — card zemin `#FAFAFA`, border `#AEAEB2` → depth hissi artar
3. Sadece fill + shadow — cesur ama TestFlight öncesi riskli

**Asset catalog:**
- `Resources/Assets.xcassets/Border.colorset/Contents.json` — light variant: `#C7C7CC → #AEAEB2`
- `Resources/Assets.xcassets/SurfacePrimary.colorset/Contents.json` — light variant: `#FFFFFF → #FAFAFA`
- Dark variant'lara dokunulmadı.

**Code:** 25 stroke satırında opacity 0.4-0.6 → 0.85 (timeline ring 0.70). Prompt: `docs/CODING_AGENT_PROMPT_OPEN_MODE_FIXES.md`.

---

### 4.2 — Arvia Rehber: CTA-zorunlu yapıdan 5 içerik tipine dönüşüm

Detaylar için yukarıdaki **Faz 1.1** bölümüne bak. Özet:

- **Sorun:** 13 kartın hepsi CTA-zorunlu → "robotik" algı
- **Çözüm:** 5 içerik tipi (CTA/Bilgi/Uyarı/Hatırlatma/Soru) + opsiyonel action + dismiss/snooze
- **Yol haritası:** v1.1 (MVP sonrası ilk güncelleme) — model + UI + 13 kart taşıma + snooze
- **v1.2+:** Konum tabanlı akıllı filtreleme, kullanıcı alışkanlık analizi (3 kez dismiss → snooze iki katına), OBD entegrasyonu
- **Açık sorular:** SwiftData migration, background task budget, hava durumu API

**Best practice referansları (Gemini raporundan):** Tesla App, FordPass (swipe-to-dismiss), Toyota MyT, BMW Connected (Proactive Care), Volvo Cars (İskandinav minimalizmi), TÜVTÜRK Portal, Apple Health (kontrol listesi), Things 3 (esnek snooze).

---

### 3.1 — Dosya Skoru: istatistik değil, eylem

Skor adı **"Dosya Tamlığı" yerine "Dosya Skoru"** (vibecoder feedback, 2 Temmuz 2026). Icon `doc.text.magnifyingglass → chart.bar.fill`.

Skor tek başına geldiğinde kullanıcı ne yapacağını bilmiyor. Checklist zaten implement edilmiş; sadece erişilebilirlik sorunu var → Garaj hero altına taşı.

Detaylar yukarıdaki **Faz 2.1**'de.

---

### 3.2 — Free limit stratejisi

`PaywallService.FreeLimits.maxVehicles = 1` korunur. Aile hesabı sorunu bilinçli olarak çözülmedi (Türkiye'de Apple Family Sharing yaygın değil).

**3.2.a — Apple Family Sharing devre dışı** — App Store Connect'te default haliyle bırakılır.

**3.2.b — Lifetime korunur** — `com.ruhsatim.pro.lifetime` korunur, paywall copy'de "Aile paylaşımı kapsamaz" notu.

**Pro stratejisi (backlog):** Akıllı içgörüler, ekspertiz doğrulama, satış dosyası linki, AI öneri, partner entegrasyonu, çoklu para birimi, beyaz etiket.

Detaylar yukarıdaki **Faz 3**'te.

---

### 3.3 — Araç Yaşam Çizgisi: signature element

Mevcut dikey liste korunur. Üzerine **kritik milestone'lara ayrıcalıklı `MilestoneCard` eklenir.**

Detaylar yukarıdaki **Faz 2.2**'de.

---

### 3.4 — Insight motoru test stratejisi

`DemoDataSeeder`'a 5 senaryo, Developer Settings UI'ından seçilebilir. DEBUG-only.

Detaylar yukarıdaki **Faz 2.3**'te.

---

### 3.5 — Onboarding → Araç Ekle: 3 adım wizard

Mevcut 6-section form yerine 3 adımlı wizard. Her adım kendi section view'ı.

Detaylar yukarıdaki **Faz 2.4**'te.

---

### 3.6 — Satış dosyası PDF'i: Arvia markası

PDF'e Arvia markası + App Store linki. Kapak footer pill, son sayfa branding.

Detaylar yukarıdaki **Faz 2.5**'te.

---

## USTA TARAFI — "Arvia Servis" (Faz 4.2, SONRA)

> **Vizyon:** Arvia'yı yalnızca araç takip uygulaması değil; araç sahibi, usta, ileride ekspertiz, sigorta ve filoları bağlayan ortak **dijital araç geçmişi platformu** hâline getirmek.

### Mimari Karar: Ayrı App Target

**"Arvia Servis" ayrı bir uygulama olacak.** Aynı bundle içinde rol seçimi DEĞİL.

```
Arvia              → Araç sahibi (mevcut uygulama)
Arvia Servis       → Usta / mekanik (yeni target)
```

**Neden ayrı app?**
- Onboarding tek: usta sadece usta ekranını görür, karmaşa yok
- App Store'da iki farklı listing → iki farklı kitle
- Kamera izni sorgusu sadece ustaya çıkar, kullanıcı uygulaması etkilenmez
- Test senaryosu bölünür, update riski azalır
- İleride Business aboneliği ayrı monetizasyon
- Her iki uygulama aynı Supabase altyapısını kullanır

### 1. Araç Paylaşım Kimliği (Public Identifier)
- [ ] **Vehicle modeline `publicIdentifier: String` alanı ekle**
  - Format: `ARV-4X9K` veya `7DHF-82KQ` (insan okunabilir)
  - SwiftData migration: yeni alan, default boş string
  - `refreshPublicIdentifier()` metodu

### 2. Kullanıcı Tarafı (Arvia): "Aracımı Paylaş"
- [ ] **Araç detay ekranında "Aracımı Paylaş" butonu** — QR kod sheet
- [ ] **QR kod oluşturma** — `CIFilter("CIQRCodeGenerator")`
  - İçerik: `https://arvia.app/v/ARV-4X9K` (URL, `arvia://` değil — uygulama yoksa web açılır)
- [ ] Paylaşım aksiyonları — ekran görüntüsü / AirDrop / mesaj

### 3. ⚠️ Onay Mekanizması (Kritik!)
- [ ] **QR okutulduğunda otomatik araç erişimi VERİLMEZ**
  ```
  QR okutulur → Araç sahibine push bildirimi:
  "Mehmet Usta aracına erişmek istiyor. Onaylıyor musun?"
  [Onayla]  [Reddet]
  ```
- [ ] Onay olmadan usta hiçbir kayıt ekleyemez
- [ ] Onaydan sonra kalıcı listeye eklenir
- [ ] "Paylaştığım Ustalar" ekranından erişim iptali

### 4. Usta Tarafı (Arvia Servis): QR Okutma
- [ ] Apple Sign In → Supabase auth → `mechanics` tablosu, `CommunityRole.mechanic`
- [ ] Ana ekran — büyük "Araç Ekle / QR Okut" butonu, araç listesi, bugünkü işler
- [ ] QR okutma — `AVFoundation` + `AVCaptureMetadataOutput`, kamera izni
- [ ] Manuel giriş fallback — textfield

### 5. Usta Veri Girişi (Tip Bazlı)

JSON yerine **ayrı tipli tablolar.** Supabase'de:

| Tablo | Alanlar | Not |
|-------|---------|-----|
| `service_records` | id, vehicle_public_id, mechanic_id, service_type, date, odometer, description, labor_cost, total_cost, next_service_date, next_service_km | Bakım kaydı |
| `expenses` | id, vehicle_public_id, mechanic_id, category, amount, date, odometer, description | Masraf |
| `part_changes` | id, vehicle_public_id, mechanic_id, part_type, brand, model, warranty_until, date, odometer | Parça değişimi |
| `service_photos` | id, vehicle_public_id, mechanic_id, related_entry_type, related_entry_id, photo_url, title | İşlem fotoğrafları |

RLS: usta sadece erişim onayı aldığı araçlara yazabilir.

### 6. Kullanıcı Onayı (Usta Kayıtları İçin)
- [ ] Usta kayıt girdikten sonra push: "Yeni bakım kaydı eklendi."
  ```
  ✔️ Onayla   ✏️ Düzenleme iste
  ```
- [ ] Onaylanmayan kayıtlar "beklemede" — timeline'da farklı görünür

### 7. CRM & "Müşterini Ara" (Business Özelliği)
- [ ] Usta ana ekran — "Bugün Aranacaklar" listesi (yaklaşan bakım, son konuşma)
- [ ] Müşteri kartı — son bakım, son harcama, sonraki öneri
- [ ] Otomatik periyotlar — yağ 1 yıl/10K km, fren 2 yıl, triger 5 yıl/60K km, lastik 4 yıl
- [ ] Local notification + uygulama içi "Yaklaşan Bakımlar"
- [ ] Business aboneliğinin temel taşı

### 8. Senkronizasyon ve Push
- [ ] Supabase Realtime — anlık senkronizasyon
- [ ] APNs — erişim onayı, yeni kayıt, bakım zamanı
- [ ] Sync stratejisi — `lastSyncedAt`, çakışmada son yazan kazanır

### 9. Gelecek Vizyonu
- [ ] NFC desteği (iPhone XS+)
- [ ] Ekspertiz entegrasyonu
- [ ] Sigorta entegrasyonu
- [ ] Filo yönetimi
- [ ] Çıkartma QR (araç sahibi yazdırıp yapıştırır)

### Implementation Roadmap

| Faz | Ne | Süre |
|-----|----|------|
| 1 | `publicIdentifier` + QR + "Aracımı Paylaş" ekranı | 2-3 gün |
| 2 | Ayrı `Arvia Servis` target, Apple Sign In, usta profili | 3-4 gün |
| 3 | QR okutma, araç eşleştirme, **onay mekanizması** | 4-5 gün |
| 4 | Tip bazlı Supabase tabloları + veri giriş + fotoğraf | 5-7 gün |
| 5 | Push + kullanıcı onayı + timeline sync | 4-5 gün |
| 6 | CRM + "Müşterini Ara" + Business aboneliği | 5-7 gün |
| | **Toplam** | **~23-31 gün** |

### Riskler

| Konu | Detay |
|------|-------|
| Kamera izni | Sadece Arvia Servis'te `NSCameraUsageDescription` |
| Onay mekanizması | Olmazsa olmaz — güvenliğin temeli |
| Veri modeli | JSON değil tip bazlı tablolar |
| App Review | İki ayrı app, iki ayrı listing — daha kolay onay |
| QR | Gerçek cihazda test edilmeli, simulator'de kamera yok |
| Monetizasyon | Kullanıcı Pro + Usta Business — iki ayrı gelir |
| QR URL formatı | `https://arvia.app/v/ARV-4X9K` — uygulama yoksa web açılır, growth sağlar |

---

## TASARIM PRENSİPLERİ (tüm yeni işler için)

Code agent şu kurallara uymalı:

1. **Token-only:** Renk `AppColors`, spacing `AppSpacing`, radius `AppRadius`, tipografi `AppTypography`, gölge `AppShadows`. Ham hex yok.
2. **AI-slop yasak:** mavi-mor gradient, glassmorphism, opacity çorbası, generic SaaS kart grid → YOK.
3. **Apple-native:** SF Symbols, native List/Form, system renkler.
4. **Anlamlı her element:** dekoratif öğe yok. Her card, her gradient, her border bir amaca hizmet eder.
5. **Boş/hata state zorunlu:** yeni eklenen her view'da empty state + error state.
6. **Accessibility:** Dynamic Type, VoiceOver label, 44pt minimum tap target.
7. **Dark mode gerçek:** sadece invert değil, el ile tasarlanmış.
8. **Bilgi > eylem:** Kullanıcıyı eyleme zorlama. CTA sadece kritik / yasal durumlarda. Bilgi/Uyarı/Hatırlatma kartlarında dismiss yeterli.

---

## AÇIK SORULAR (sonraya kalanlar)

- [ ] **Lifetime ürünü** korunacak mı çıkarılacak mı? (Conversion verisi gelince karar)
- [ ] **Yeni Pro değerleri** (akıllı insight, ekspertiz doğrulama, AI öneri) için **backlog PR'ı** yazılacak (ayrı dosya).
- [ ] **App Store URL** — submit sonrası `PDFExportService` placeholder'ı gerçek URL ile değiştirilecek.
- [ ] **Hesap silmenin Supabase tarafı** — manuel test edilecek.
- [ ] **Review'da hesap silme flow** gerçekten çalışıyor mu doğrulanacak.
- [ ] **Paywall context'leri** implement edilince, her context için copy review edilecek.
- [ ] **iCloud/CloudKit sync** altyapı hazır, kapalı. Açılma kararı kullanıcı verisi gelince.
- [ ] **SwiftData Migration (Faz 1.1)** — zorunlu `action` → opsiyonel `action` + yeni `contentKind`. Veri kaybı olmamalı.
- [ ] **Background task budget (Faz 1.1)** — kural motoru arka plan sıklığı.
- [ ] **Hava durumu API (Faz 1.1+)** — bölgesel kış/DPF uyarıları için gizlilik + maliyet dengesi.

---

## İLGİLİ DOSYALAR

- `01_DESIGN.md` — tasarım anayasası (token-only, AI-slop yasak)
- `02_PRODUCT_SCOPE.md` — feature haritası
- `docs/RESEARCH_ARVIA_GUIDE_SCENARIOS.md` — Gemini Deep Research raporu (670 satır, 39 kaynak)
- `docs/RESEARCH_PROMPT_ARVIA_GUIDE_SCENARIOS.md` — Gemini promptu
- `docs/CODING_AGENT_PROMPT_OPEN_MODE_FIXES.md` — Karar 4.1 code agent promptu
- `docs/CODING_AGENT_PROMPT_MVP_FIXES.md` — MVP öncesi bug fix promptu
- `docs/CODING_AGENT_PROMPT_V1.1_PRODUCT.md` — v1.1 ürün promptu (genişletilecek)