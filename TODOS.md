# TODOS — Gelecek Planları

## iCloud Sync

- **Durum:** Altyapı hazır, kapalı
- **Ne yapılacak:**
  - [ ] Xcode → Signing & Capabilities → + iCloud → CloudKit işaretle
  - [ ] Container: `iCloud.com.ruhsatim.app` ekle
  - [ ] `AppEnvironment.isCloudKitSyncEnabled = true`
- **Not:** Tüm SwiftData modelleri CloudKit uyumlu. Veri kaybı olmadan cihazlar arası senkronizasyon sağlanır.
- **Etki:** Apple girişi yapan kullanıcıların araç, belge, hatırlatıcı, masraf verileri tüm cihazlarında senkronize olur. Topluluk profiliyle de eşleşir.

## Usta / Servis Paneli — "Arvia Servis"

- **Durum:** Planlama aşaması
- **Vizyon:** Arvia'yı yalnızca araç takip uygulaması değil; araç sahibi, usta, ileride ekspertiz, sigorta ve filoları bağlayan ortak **dijital araç geçmişi platformu** hâline getirmek.

### 🏗️ Mimari Karar: Ayrı App Target

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
  - İnsan okunabilir, telefonda söylenebilir format: `ARV-4X9K` veya `7DHF-82KQ`
  - SwiftData migration: yeni alan, default boş string
  - `refreshPublicIdentifier()` metodu ile istenilen zaman yeniden üretilebilir

### 2. Kullanıcı Tarafı (Arvia): "Aracımı Paylaş"
- [ ] **Araç detay ekranında "Aracımı Paylaş" butonu**
  - QR kod gösteren tam ekran sheet
- [ ] **QR kod oluşturma**
  - `CIFilter(name: "CIQRCodeGenerator")` ile QR üretimi
  - İçerik: `https://arvia.app/v/ARV-4X9K` (URL formatı, `arvia://` değil!)
  - **Neden URL:** Uygulama yüklü değilse web açılır → "Arvia'yı indir" denir → growth sağlar
  - SwiftUI Image view: `.interpolation(.none)` + `resizable()`
- [ ] **QR altında gösterilenler:**
  - Araç plaka, marka/model
  - "Bu kodu ustana göster, bakım kayıtlarını girsin"
  - Kod metni: `ARV-4X9K` (kopyalanabilir, manuel girilebilir)
- [ ] **Paylaşım aksiyonları:** Ekran görüntüsü kaydet / AirDrop / mesajla gönder

### 3. ⚠️ Onay Mekanizması (Kritik!)
- [ ] **QR okutulduğunda otomatik araç erişimi VERİLMEZ**
  ```
  QR okutulur → Araç sahibine push bildirimi gider:
  
  "Mehmet Usta aracına erişmek istiyor.
   Onaylıyor musun?"
  
  [Onayla]  [Reddet]
  ```
- [ ] Onay olmadan usta **hiçbir kayıt ekleyemez**, araç detayını göremez
- [ ] Onaydan sonra usta o aracı kalıcı listesine ekler, tekrar QR okutmaya gerek kalmaz
- [ ] Araç sahibi Settings → "Paylaştığım Ustalar" ekranından erişimi iptal edebilir

### 4. Usta Tarafı (Arvia Servis): QR Okutma

- [ ] **Usta giriş ekranı (Arvia Servis app)**
  - Apple Sign In → Supabase auth (CommunityAuthService)
  - Usta profili: `mechanics` tablosu, `CommunityRole.mechanic`
- [ ] **Usta ana ekranı:**
  - Büyük "Araç Ekle / QR Okut" butonu
  - Araçlarım listesi (onaylanmış, daha önce eklenmiş)
  - Bugün yapılacak işler / son işlemler
- [ ] **QR kod okutma**
  - `AVFoundation` + `AVCaptureMetadataOutput` ile kamera tarama
  - `UIViewControllerRepresentable` wrapper → `CodeScannerView`
  - Kamera izni: `NSCameraUsageDescription` Info.plist'e eklenmeli
  - Manuel giriş fallback: "Araç Kodu" textfield
- [ ] **Okutma sonrası akış:**
  ```
  QR okutulur → publicIdentifier çözülür
  → "Araç sahibine onay bildirimi gönderildi" mesajı
  → Onay gelince araç ustanın listesine düşer
  ```

### 5. Usta Veri Girişi (Tip Bazlı Veri Modeli)

**JSON `service_entries` tablosu YERİNE ayrı tipli tablolar.** Raporlama, arama ve ileri entegrasyon için zorunlu.

- [ ] **Supabase tabloları (Arvia Servis yazar, Arvia okur):**

| Tablo | Alanlar | Not |
|-------|---------|-----|
| `service_records` | `id`, `vehicle_public_id`, `mechanic_id`, `service_type`, `date`, `odometer`, `description`, `labor_cost`, `total_cost`, `next_service_date`, `next_service_km`, `created_at` | Bakım kaydı |
| `expenses` | `id`, `vehicle_public_id`, `mechanic_id`, `category`, `amount`, `date`, `odometer`, `description`, `created_at` | Masraf |
| `part_changes` | `id`, `vehicle_public_id`, `mechanic_id`, `part_type`, `brand`, `model`, `warranty_until`, `date`, `odometer`, `created_at` | Parça değişimi |
| `service_photos` | `id`, `vehicle_public_id`, `mechanic_id`, `related_entry_type`, `related_entry_id`, `photo_url`, `title`, `created_at` | İşlem fotoğrafları |

- [ ] **RLS kuralları:** Usta sadece erişim onayı aldığı araçlara yazabilir
- [ ] **Usta hangi verileri girebilir:**
  - Servis kaydı (tarih, km, yapılan iş, işçilik, toplam)
  - Masraf (kategori, tutar, tarih)
  - Parça değişimi (hangi parça, marka, garanti süresi)
  - **Fotoğraf** (eski fren balatası, yeni balata, yağ filtresi gibi) → timeline'da araç sahibine güven oluşturur
  - Serbest not / gözlem

### 6. ⚠️ Kullanıcı Onayı (Usta Kayıtları İçin)
- [ ] **Usta kayıt girdikten sonra araç sahibine push gider:**
  ```
  "Yeni bakım kaydı eklendi."
  ✔️ Onayla   ✏️ Düzenleme iste
  ```
- [ ] Onaylanmayan kayıtlar "beklemede" olarak işaretlenir, timeline'da farklı görünür
- [ ] Bu mekanizma kötü niyetli/hatalı kayıt girişini engeller

### 7. CRM & "Müşterini Ara" (Business Özelliği)
- [ ] **Usta ana ekranı — Bugün Aranacaklar:**
  ```
  ⚠️ Ahmet Yılmaz
  Hyundai i20 — Yağ bakımı
  3 gün kaldı
  [Ara]
  ```
- [ ] **Müşteri kartı (CRM):**
  ```
  Son bakım: 145 gün önce
  Son harcama: 12.400 TL
  En son konuşma: 8 ay önce
  Sonraki öneri: Klima bakımı
  ```
- [ ] **Otomatik periyotlar:**
  - Yağ bakımı: 1 yıl / 10.000 km
  - Fren balatası: 2 yıl
  - Trigon kayışı: 5 yıl / 60.000 km
  - Lastik: 4 yıl
  - Genel bakım: 1 yıl
- [ ] **Bildirim:** Local notification + uygulama içi "Yaklaşan Bakımlar" listesi
- [ ] Bu özellik **Business aboneliğinin** temel taşı — ustalar müşteri kaybetmemek için para vermeye razı

### 8. Senkronizasyon ve Push
- [ ] **Supabase Realtime** ile anlık senkronizasyon
  - Usta kayıt girer → araç sahibi anında görür
  - Kullanıcı onaylar/reddeder → usta anında görür
- [ ] **Push notification (APNs):**
  - Erişim onayı istendi
  - Yeni bakım kaydı eklendi (onay beklemede)
  - Bakım zamanı yaklaştı (ustaya)
- [ ] **Sync stratejisi:** `lastSyncedAt` ile sadece yeni kayıtlar çekilir. Çakışmada son yazan kazanır.

### 9. Gelecek Vizyonu

- [ ] **NFC desteği:** iPhone-to-iPhone NFC ile QR yerine telefon yaklaştırarak aracı paylaşma (iPhone XS ve üstü destekliyor)
- [ ] **Ekspertiz entegrasyonu:** Ekspertiz firmaları aynı sistem üzerinden araç geçmişini görüntüleyebilir
- [ ] **Sigorta entegrasyonu:** Hasar/poliçe bilgileri eklenebilir
- [ ] **Filo yönetimi:** Şirketler filolarını Arvia üzerinden yönetebilir
- [ ] **Çıkartma QR:** Araç sahibi QR'ı yazdırıp aracına yapıştırabilir (gerçek dünyada kullanım)

---

### Implementation Roadmap

| Faz | Ne | Süre | Uygulama |
|-----|----|------|----------|
| **1** | `publicIdentifier` + QR oluşturma + "Aracımı Paylaş" ekranı | 2-3 gün | Arvia |
| **2** | Ayrı `Arvia Servis` target, Apple Sign In, usta profili | 3-4 gün | Arvia Servis |
| **3** | QR okutma, araç eşleştirme, **araç sahibi onay mekanizması** | 4-5 gün | Arvia + Arvia Servis |
| **4** | Tip bazlı Supabase tabloları + veri giriş formları + fotoğraf | 5-7 gün | Arvia Servis |
| **5** | Push notification + kullanıcı onayı + timeline sync | 4-5 gün | Her ikisi |
| **6** | CRM + "Müşterini Ara" + Business aboneliği | 5-7 gün | Arvia Servis |
| | **Toplam** | **~23-31 gün** | |

---

### Önemli Notlar / Riskler

| Konu | Detay |
|------|-------|
| 📱 Kamera izni | Sadece Arvia Servis'te `NSCameraUsageDescription` |
| 🔐 Onay mekanizması | Olmazsa olmaz — güvenliğin temeli |
| 🔄 Veri modeli | JSON değil tip bazlı tablolar — ileride çok rahatlatır |
| 🏪 App Review | İki ayrı app, iki ayrı listing — daha kolay onay |
| 📦 Mevcut altyapı | `CommunityAuthService`, Supabase RLS yapısı, form pattern'leri hazır |
| 🧪 QR | Gerçek cihazda test edilmeli, simulator'de kamera yok |
| 💰 Monetizasyon | Kullanıcı Pro (çoklu araç) + Usta Business (CRM) — iki ayrı gelir |
| 🌐 QR URL formatı | `https://arvia.app/v/ARV-4X9K` — uygulama yoksa web açılır, growth sağlar |
