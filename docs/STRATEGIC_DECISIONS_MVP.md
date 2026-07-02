# Arvia — Stratejik Kararlar Manifestosu (MVP & v1.1)

> **Tarih:** 2 Temmuz 2026
> **Hazırlayan:** Fatih + Mavis
> **Bağlam:** App Store submit öncesi + ilk güncelleme planı
> **Referans:** `00_README.md` (genel bakış), `02_PRODUCT_SCOPE.md` (feature haritası), `01_DESIGN.md` (tasarım anayasası)

Bu dosya, MVP öncesi ve v1.1'de uygulanacak **stratejik ürün kararlarını**, **nedenlerini** ve **nasıl uygulanacağını** tek noktada toplar. Yeni geliştirici/agent bu dosyayı okuyarak bağlamı kapar.

---

## Karar tablosu (özet)

| # | Karar | Uygulama | Bucket | Tahmini iş |
|---|-------|----------|--------|------------|
| 3.1 | Dosya Skoru = checklist olarak Garaj'da (vibecoder feedback ile adı "Dosya Tamlığı" → "Dosya Skoru" olarak değişti) | `DosyaniTamamlaChecklist` zaten var; Garaj'da bugünGarageSection altına/üstüne taşı | 1.10 (BUCKET 1) | 2 saat |
| 3.2 | Free = 1 araç, katı kural. Aile hesabı çözülmedi. Pro'ya ileride yeni değerler eklenecek. | Kod değişikliği yok, sadece bu manifesto. (Bkz. aşağıdaki "Pro stratejisi" bölümü) | — | — |
| 3.2.a | Apple Family Sharing **devre dışı**. Türkiye'de kullanımı düşük. | App Store Connect'te subscription'lara dokunma; default haliyle bırak. | — | — |
| 3.2.b | Lifetime ürünü **şimdilik korunur**, karar açık. İleride yeniden değerlendirilir. | Kod değişikliği yok. Fiyatlandırma sayfasında framing net olsun: "Kendi hesabınızda ömür boyu Pro." | — | — |
| 3.3 | Timeline = dikey liste + kritik milestone'lara ayrıcalıklı kart | `lifeTimelineSection`'a milestone detection + özel `MilestoneCard` view | 2.6 (BUCKET 2) | 1 gün |
| 3.4 | Insight test stratejisi = `DemoDataSeeder`'a 5 senaryo | `seedInsightScenarios()` + Developer Settings UI | 2.7 (BUCKET 2) | 1 gün |
| 3.5 | Onboarding sonrası araç ekleme = 3 adım wizard | `VehicleFormView` → `VehicleFormWizardView` (3 adım: tanımla / durum / sıradaki işler) | 2.8 (BUCKET 2) | 3-4 gün |
| 3.6 | Satış dosyası PDF'ine Arvia markası + App Store linki | `PDFExportService`'e brand header/footer | 1.11 (BUCKET 1) | 30 dakika |

---

## 3.1 — Dosya Skoru: istatistik değil, eylem

**Karar:** Skor adı **"Dosya Tamlığı" yerine "Dosya Skoru"** (vibecoder feedback, 2 Temmuz 2026). "Tamlık" kelimesi "her şey tamam" çağrışımı yapıyordu; "Skor" daha nötr ve "aracın dosyası ne kadar dokümante" anlamını doğru taşıyor. Aynı zamanda icon da `doc.text.magnifyingglass` → `chart.bar.fill` olarak değişti.

`DosyaniTamamlaChecklist` component'i zaten var (Araç Detay'da gösteriliyor). Bunu **Garaj hero altına** da taşı, böylece kullanıcı arabasını ekledikten sonra ilk gördüğü yerde "3 adım kaldı" görsün.

**Neden:** Skor tek başına geldiğinde kullanıcı ne yapacağını bilmiyor. Checklist zaten implement edilmiş; sadece **erişilebilirlik** sorunu var.

**Nasıl:**
- `Features/Garage/GarageView.swift` `garageContent` body'sinde `bugünGarageSection` veya `quickActionsSection`'dan birinin yanına/altına yerleştir.
- Aynı `DosyaniTamamlaChecklist` view'i reuse edilir (component zaten paylaşılabilir).
- 5 kriterden <5 tamamlandıysa göster, hepsi tamamsa gizle (component zaten bunu yapıyor).
- Acceptance: Araç eklenip muayene/sigorta/ilk masraf/ilk belge girilmediğinde Garaj'da checklist görünür. Tüm 5 kriter tamamlanınca gizlenir.

**Dosya Skoru hesaplama mantığı (2 Temmuz 2026):**

| Kategori | Puan | Koşul |
|----------|------|-------|
| Temel bilgiler | 40 | plaka + marka + model + yıl + km + vites + motor (motosiklet) + satın alma tarihi (her biri 5) |
| Araç fotoğrafı | 10 | `vehicle.photoFileName != nil` |
| Belgeler | 25 | En az 1 belge 15p, 3+ farklı belge tipi 10p (**belge olmadan %100 olamaz**) |
| Hatırlatıcı | 10 | En az 1 aktif reminder |
| Masraf | 8 | En az 1 expense |
| Bakım | 7 | En az 1 service record |
| **Toplam** | **100** | |

Önceki mantıkta belge puan olarak hiç sayılmıyordu; yeni mantıkta belge yoksa max %75'e ulaşılabilir. Bu sayede "hiç belge yok %100" sorunu ortadan kalktı.

---

## 3.2 — Free limit stratejisi

### Temel karar: 1 araç free, katı kural (bugünkü hali)

`PaywallService.FreeLimits.maxVehicles = 1`. 2+ araç = Pro. Bu **korunur**.

### Aile hesabı sorunu: çözülmedi, sonraya not

3 araçlı bir hanede 3 kişi ayrı ayrı hesap açıp 1'er araç ekleyebilir, hepsi free kalır. **Türkiye'de Apple Family Sharing yaygın değil**, bu yüzden buradan gelir elde etmek için oyun alanı yok. Karar: **aile hesabı sorununu bugün çözmüyoruz**, bilinçli olarak.

### Pro stratejisi: ileride Pro'ya yeni değerler eklenecek

Bugün Pro'nun tek somut değeri: **sınırsız araç**. Bu zayıf. **Gelecek Pro değerleri (backlog):**

1. **Akıllı içgörüler (Insights Pro)**
   - "Bu yıl geçen yıla göre %23 daha fazla masraf ettin, çoğu yakıt."
   - "Benzer kullanıcılar 50.000 km'de fren balatası değiştiriyor, senin 62.000 km oldu."
   - Free sürümde sadece temel grafikler; Pro'da pattern analizi.

2. **Ekspertiz doğrulama rozeti**
   - TÜVTÜRK raporlarını Arvia üzerinden doğrula → alıcıya "doğrulanmış" rozeti göster.
   - Bu doğrudan alıcı güveni → daha hızlı satış → Arvia'ya değer.

3. **Sınırsız satış dosyası paylaşımı + link ile paylaşım**
   - Bugün PDF (sınırsız). İleride: süreli public link, görüntülenme sayısı, alıcı soru-cevap.

4. **AI destekli hatırlatıcı önerisi**
   - "Kullanıcı 60.000 km'yi geçti, otomatik fren kontrolü hatırlatıcısı öner."

5. **Partner entegrasyonu (usta/expertiz indirimi)**
   - Anayasadaki ileriye dönük vizyon: doğrulanmış partner'lardan indirim.

6. **Çoklu para birimi / kur dönüşümü**
   - "Aracımı TL/Euro olarak da takip et" (yurt dışından alınan araçlar için).

7. **Beyaz etiket satıcı paketi (V2)**
   - "Aracımı satarken kendi aracımın Arvia dosyasını oluştur" → galerici paketi.

**Bu liste `docs/PRODUCT_BACKLOG.md` veya `02_PRODUCT_SCOPE.md` V2 bölümüne eklenecek** (TODO: ayrıca yapılacak). Şu an sadece "yön" olarak kayıt altında.

### 3.2.a — Apple Family Sharing: devre dışı

App Store Connect'te subscription'ları "Family Sharable" olarak **işaretleme**. Default haliyle kalır (auto-renewable olmasına rağmen paylaşıma kapalı).

**Gerekçe:** Türkiye'de aile planı kullanım oranı düşük. Açmak gelir kaybına yol açmaz (Türkiye pazarında aile planı alımı sınırlı), ama App Store review sürecinde ek kontrol adımı yaratabilir.

### 3.2.b — Lifetime: şimdilik korunur

`com.ruhsatim.pro.lifetime` ürünü **korunur**. Framing paywall'da: "Tek seferlik ödeme, kendi hesabınızda ömür boyu Pro." Aile paylaşımına girmez (non-consumable). Bunu paywall copy'sinde **açıkça belirtme** (örn. ufak bir "Aile paylaşımı kapsamaz" notu).

**İleride yeniden değerlendirilecek** (kullanıcı trafiği ve conversion verisi gelince).

---

## 3.3 — Araç Yaşam Çizgisi: signature element

**Karar:** Mevcut dikey liste **korunur**. Üzerine **kritik milestone'lara ayrıcalıklı `MilestoneCard` eklenir.**

**Kritik milestone'lar (şu kriterler):**
1. **Araç satın alma** (`Vehicle.purchaseDate` set edilmişse)
2. **İlk büyük bakım** (parts_cost > 5000 TRY VEYA service_type = major)
3. **Ekspertiz raporu** (any inspection)
4. **Satış dosyası oluşturulmuş** (any SaleFile)
5. **5+ yıl sahiplik dönüm noktası** (sahiplik yılı)

**Nasıl:**
- `Features/VehicleDetail/` altına `VehicleDetailMilestoneCard.swift` ekle.
- Mevcut `lifeTimelineSection` içinde her event'i milestone kriterlerine göre değerlendir.
- Milestone olan event'ler `MilestoneCard`'la render edilir (daha büyük padding, accent border, ikon çevresinde hafif ring).
- Diğer event'ler mevcut sade liste hali.

**Acceptance criteria:**
- Yeni eklenen araç + hiç kayıt yok → timeline "henüz kayıt yok" empty state (zaten var).
- purchaseDate set + birkaç bakım → satın alma milestone kartı, bakımlar liste.
- Ekspertiz eklendikten sonra → ekspertiz milestone kartı, satın alma da milestone.

---

## 3.4 — Insight motoru test stratejisi

**Karar:** `DemoDataSeeder`'a 5 senaryo ekle. Developer Settings UI'ında seçilebilir.

**Senaryolar:**

| Senaryo | Durum | Test amacı |
|---------|-------|------------|
| `.empty` | Hiç araç yok | Empty state, "ilk aracını ekle" CTA, hata yok |
| `.singleReminder` | 1 araç, 1 reminder (3 ay sonra muayene) | Sakin state, "yaklaşan" tipi insight |
| `.overdueState` | 1 araç, 1 overdue reminder | Kırmızı, primary, üstte |
| `.busyState` | 1 araç, 5 reminder (1 overdue, 1 today, 3 future) | Çakışan insight'lar, öncelik sıralaması |
| `.quietGood` | 1 araç, tüm reminders completed | Sessiz iyi hal, "tamam" mesajı |

**Nasıl:**
- `Models/MockDataProvider.swift` veya `Services/DemoDataSeeder.swift` (hangisinde yer alıyorsa) `seedInsightScenarios(_:)` ekle.
- Mevcut `DeveloperSection` (`SettingsView.swift`) içine "Insight Senaryoları" submenu ekle.
- Senaryo seçilince: mevcut araçlar temizlenir, yeni state kurulur, Garaj sekmesine navigate.

**Acceptance criteria:**
- 5 senaryo tek tuşla yüklenebilir.
- Her senaryo Garaj ve Araç Detay'da doğru insight'ları gösterir.
- Dismiss/Snooze mekanizması her senaryoda test edilebilir.
- Build'de DEBUG-only — release'de yer almaz.

**Bonus:** Aynı senaryolar App Store ekran görüntüleri (marketing material) için de kullanılabilir.

---

## 3.5 — Onboarding → Araç Ekle: 3 adım wizard

**Karar:** Mevcut 6-section'lı `VehicleFormView` yerine 3 adımlı wizard.

**Adımlar:**

1. **Tanımla** (zorunlu)
   - Araç türü (otomobil / motosiklet)
   - Plaka
   - Marka (picker + özel)
   - Model (picker + özel)
   - Yıl

2. **Durumu** (opsiyonel ama hızlı)
   - Güncel km
   - Yakıt tipi
   - Vites tipi
   - Kullanım tipi (kişisel / şirket / ticari)
   - Fotoğraf (opsiyonel)

3. **Sıradaki işler** (opsiyonel)
   - "İlk hatırlatıcı eklemek ister misin?" — 3 hazır buton:
     - **Muayene** (default 2 yıl sonra)
     - **Trafik sigortası** (default 1 yıl sonra)
     - **MTV** (otomatik olarak yılın ilk/2. yarısı)
   - Atla seçeneği

**Wizard UX kuralları:**
- Üstte progress indicator (3 nokta veya 3 step pill'i)
- Her adım sonunda "Devam" (primary) + önceki adıma "Geri" (text)
- Adım 1'de plaka+marka+model boşsa "Devam" disabled; veya kısmi validation (sadece plaka zorunlu).
- Son adımda "Aracı Ekle" CTA'sı.
- Back gesture (iOS edge swipe) çalışsın.

**Nasıl:**
- `Features/Garage/VehicleFormView.swift` korunur (gerekirse).
- `Features/Garage/VehicleFormWizardView.swift` yeni dosya.
- 3 adımı yöneten state: `@State currentStep: WizardStep` enum.
- Her adım kendi section view'ı.

**Acceptance criteria:**
- Onboarding → "İlk aracımı ekle" → wizard step 1 açılır.
- Step 1'de sadece plaka girilip step 2'ye geçilir; geri dönünce plaka hâlâ dolu.
- Step 3'te "Muayene" seçilirse reminder otomatik oluşur.
- Skip seçilirse sadece araç kaydedilir, hatırlatıcı oluşmaz.

---

## 3.6 — Satış dosyası PDF'i: Arvia markası

**Karar:** PDF'e Arvia markası + App Store linki ekle.

**İçerik:**

**Kapak sayfası (mevcut):**
- Başlık: "Satış Dosyası" (zaten var)
- Araç adı + plaka (zaten var)
- **EK:** Footer pill: "Arvia ile oluşturuldu" + arvia.app kısa URL

**Son sayfa (yeni):**
- Büyük Arvia logosu (SF Symbol + wordmark — text tabanlı yeterli)
- "Aracının dijital yaşam dosyasını yönet"
- App Store badge: "App Store'dan İndir" (gerçek badge yerine text link yeterli MVP'de; ileride gerçek badge)
- QR code (opsiyonel, v1.1 — `arvia.app` URL'sini encode et)

**İçerik sayfaları (mevcut):**
- Dokunma, sadece footer pill ekle (sayfa numarası yanında).

**Nasıl:**
- `Services/PDFExportService.swift`:
  - Yeni private method `drawBrandFooter(context:pageIndex:totalPages:)`.
  - Yeni private method `drawCoverPage(...)` — mevcut kapak implementasyonuna footer pill ekle.
  - Yeni private method `drawLastPage(context:)` — Arvia branding + App Store link.
- App Store link: `https://apps.apple.com/app/arvia/[APP_ID]` — APP_ID placeholder, **manuel tamamlanacak** (App Store Connect'ten URL alındıktan sonra).

**Acceptance criteria:**
- PDF oluşturulduğunda kapakta "Arvia ile oluşturuldu — arvia.app" görünür.
- Son sayfada Arvia branding + App Store linki görünür.
- Türkçe + İngilizce metin (PDF dil seçimi yapılmamışsa Türkçe).

---

## Tasarım prensibi notları (yeni işler için)

Code agent şu kurallara uymalı:

1. **Token-only:** Renk `AppColors`, spacing `AppSpacing`, radius `AppRadius`, tipografi `AppTypography`, gölge `AppShadows`. Ham hex yok.
2. **AI-slop yasak:** mavi-mor gradient, glassmorphism, opacity çorbası, generic SaaS kart grid → YOK.
3. **Apple-native:** SF Symbols, native List/Form, system renkler.
4. **Anlamlı her element:** dekoratif öğe yok. Her card, her gradient, her border bir amaca hizmet eder.
5. **Boş/hata state zorunlu:** yeni eklenen her view'da empty state + error state.
6. **Accessibility:** Dynamic Type, VoiceOver label, 44pt minimum tap target.
7. **Dark mode gerçek:** sadece invert değil, el ile tasarlanmış.

---

## Açık sorular (sonraya kalanlar)

- [ ] **Lifetime ürünü** korunacak mı çıkarılacak mı? (Conversion verisi gelince karar)
- [ ] **Yeni Pro değerleri** (akıllı insight, ekspertiz doğrulama, AI öneri) için **backlog PR'ı** yazılacak (ayrı dosya).
- [ ] **App Store URL** — submit sonrası `PDFExportService` placeholder'ı gerçek URL ile değiştirilecek.
- [ ] **Hesap silmenin Supabase tarafı** — manuel test edildi mi? (Kullanıcı "etmedim" dedi)
- [ ] **Review'da hesap silme flow** gerçekten çalışıyor mu? (Kullanıcı test etmedi)
- [ ] **Paywall context'leri** (BUCKET 1.1) implement edilince, her context için copy review edilecek.
- [ ] **iCloud/CloudKit sync** altyapısı hazır, kapalı. Açılma kararı kullanıcı verisi gelince.

---

## Nasıl kullanılır bu dosya

1. **Yeni code agent başlatırken:** Bu dosyayı + `01_DESIGN.md` + ilgili prompt dosyasını (`CODING_AGENT_PROMPT_MVP_FIXES.md` veya `CODING_AGENT_PROMPT_V1.1_PRODUCT.md`) okut.
2. **PR review'da:** PR açıklamasında bu manifesto'dan referans ver (`Karar 3.6 gereği...`).
3. **Ürün tartışmasında:** Karar değişirse bu dosyada değiştir, commit'le. Manifesto canlı dokümandır.
4. **Yeni geliştirici katılırsa:** İlk okuduğu dosya bu olsun.
