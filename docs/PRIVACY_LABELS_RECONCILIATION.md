# Arvia — App Privacy Labels Reconciliation

> Bu dosya, `Resources/PrivacyInfo.xcprivacy` ile App Store Connect privacy labels arasında mutabakat sağlamak içindir.
> App Store Connect'te privacy sorularını yanıtlarken bu tabloyu referans al.
>
> **Son güncelleme:** 2026-07-05 (Bulut Yapay Zekâ + Kamera/Fiş Tarama eklendi)
> **Referans:** `docs/lastchecks.md` madde 8, `docs/appstore-yayin-rehberi.html`

---

## Collected Data Types (Toplanan Veri Türleri)

| # | PrivacyInfo Key | Veri Türü | Linked to User | Tracking | Purpose | App Store Sorusu | Önerilen Yanıt |
|---|----------------|-----------|----------------|----------|---------|------------------|---------------|
| 1 | `NSPrivacyCollectedDataTypeOtherUserContent` | User Generated Content (topluluk gönderi/yorum) | Yes | No | App Functionality | "Does your app collect any data?" → User Content → "Yes, collected" | Yes, linked to user identity, for app functionality. Supabase'te saklanır. |
| 2 | `NSPrivacyCollectedDataTypeName` | Name (görünen ad, kullanıcı adı) | Yes | No | App Functionality | "Does your app collect any data?" → Name → "Yes, collected" | Yes, linked to user identity, for app functionality (topluluk profili). Supabase'te saklanır. |
| 3 | `NSPrivacyCollectedDataTypeEmailAddress` | Email Address (Apple Sign In) | Yes | No | App Functionality | "Does your app collect any data?" → Email Address → "Yes, collected" | Yes, linked to user identity, for app functionality (Supabase Auth). Apple Private Relay ile gizlenmiş e-posta da olabilir. |
| 4 | `NSPrivacyCollectedDataTypePhotosorVideos` | Photos or Videos (belge fotoğrafları) | No | No | App Functionality | "Does your app collect any data?" → Photos or Videos → "Yes, collected" | Yes, NOT linked to user identity, for app functionality. Yerel cihazda saklanır, cihaz dışına gönderilmez (iCloud sync opsiyonel). |
| 5 | `NSPrivacyCollectedDataTypePurchaseHistory` | Purchase History (StoreKit abonelik) | No | No | App Functionality | "Does your app collect any data?" → Purchase History → "Yes, collected" | Yes, NOT linked to user identity, for app functionality. StoreKit 2 tarafından yönetilir, uygulama kendi veritabanını tutmaz. |
| 6 | `NSPrivacyCollectedDataTypeOtherUserContent` (Bulut AI) | Other User Content — maskelenmiş fiş/araç metni | No | No | App Functionality | "Other Data" → "Yes, collected" | Yes, NOT linked to identity. **Yalnızca kullanıcı Bulut AI'yı açarsa** gönderilir (varsayılan kapalı). PII cihazda maskelenir; ara sunucu model girdi/çıktısını saklamaz. Pro doğrulaması için App Store makbuzu Apple'a iletilir ve yalnızca hash'lenmiş işlem kimliğine bağlı kota sayacı tutulur. Zaten #1 (User Content) altında beyan edildiyse ayrı satır gerekmez; ancak kaynağı ayrı olduğu için ("Other") not düş. |

> **Bulut Yapay Zekâ notu:** Özellik varsayılan kapalı ve opt-in olsa da, uygulama bu veriyi gönderme *yeteneğine* sahip olduğu için App Privacy'de beyan edilir. "Linked to You" = **No** (anonim), "Used for Tracking" = **No**. Sağlayıcı: DeepSeek (ara sunucu: Vercel). Bu, tracking değil app-functionality amaçlıdır.

> **Kamera notu:** `NSCameraUsageDescription` bir *purpose string*'tir, Required Reason API değildir. Kameradan gelen görüntüler cihazda işlenir (Vision OCR) ve #4 (Photos or Videos) altında zaten kapsanır; yeni bir veri türü eklemez.

---

## Data Not Collected (Toplanmayan Veriler)

Aşağıdaki veri türleri uygulama tarafından **toplanmaz**. App Store'da "No, I do not collect data from this app" seçeneğinin altında bu türler için **hiçbir şey işaretlenmemelidir**:

- Precise Location
- Coarse Location
- Health & Fitness
- Financial Info (ödeme bilgisi — StoreKit Apple tarafından yönetilir, uygulama erişmez)
- Contact Info (telefon, fiziksel adres — toplanmaz)
- Contacts
- Browsing History
- Search History
- Identifiers (Device ID — kullanılmaz)
- Sensitive Info
- Diagnostics
- Surroundings (audio/video)

---

## Tracking

| PrivacyInfo Key | Değer | App Store Yanıtı |
|----------------|-------|-----------------|
| `NSPrivacyTracking` | `false` | "No, I do not track users" |
| `NSPrivacyTrackingDomains` | `[]` (boş) | Tracking domains yok |

**Not:** Uygulama ATT (App Tracking Transparency) kullanmaz. Kullanıcıyı izlemez.

---

## Required Reason APIs (Gerekçeli API Kullanımı)

| # | API Type | Reason Code | Açıklama | App Store'da Gösterilecek Mi? |
|---|----------|-------------|----------|------------------------------|
| 1 | `NSPrivacyAccessedAPICategoryFileTimestamp` | `C617.1` | FileManager ile dosya damgalarına erişim — yalnızca uygulamanın kendi sandbox'ındaki belge dosyaları için | Evet, Required Reason API listesinde gösterilmeli |
| 2 | `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` | UserDefaults — yalnızca uygulamanın kendi ayar/durumu için (Pro durumu, onboarding, tema vb.) | Evet, Required Reason API listesinde gösterilmeli |
| 3 | `NSPrivacyAccessedAPICategoryDiskSpace` | `7D9E.1` | Disk alanı — DocumentStorageService depolama kullanımı bilgisi için | Evet, Required Reason API listesinde gösterilmeli |

---

## Eksik / Yapılması Gerekenler

- [ ] **Supabase domain listesi:** `lastchecks.md` madde 8'de belirtildiği gibi, Supabase domain'leri (`*.supabase.co`) `NSPrivacyTrackingDomains`'e eklenmemiş. Supabase **tracking amaçlı değil**, app functionality amaçlı kullanılıyor. Dolayısıyla tracking domains'te gösterilmesi gerekmez, ancak App Store review'de sorulursa "veri depolama için üçüncü taraf hizmet" olarak açıklanmalı.

- [ ] **App Store Connect'te privacy labels:** Bu dosyadaki tabloya göre App Store Connect → App Privacy → Privacy Nutrition Label kısmında yanıtla. Her veri türü için "Yes, collected" ve uygun purpose'ı seç.

---

## App Store Connect Hızlı Referans

App Store Connect'te şu sırayla ilerle:

1. **Privacy Policy URL:** Uygulamanın gizlilik politikası URL'si (varsa)
2. **Data Collection:** Yukarıdaki 5 veri türü için "Yes, collected from this app"
3. **Data Linked to User:** Name, Email, User Content → Yes. Photos, Purchase History → No.
4. **Tracking:** "No, I do not track"
5. **Required Reason APIs:** 3 API için onay kutusu

---

## Kaynak Dosya

`Resources/PrivacyInfo.xcprivacy` — Bu dosya Apple'ın privacy manifest formatındadır ve Xcode tarafından otomatik okunur. App Store'a gönderirken bu manifest referans alınır.
