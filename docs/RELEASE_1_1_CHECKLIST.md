# Arvia 1.1.0 — Yayın Kontrol Listesi

Bu liste `1.1.0 (4)` sürümünün canlı servis ve App Store geçiş kapısıdır. Yerel
ürün kapsamı `RELEASE_1_1_PRODUCT_PACKAGE.md`, değişiklik özeti kökteki
`CHANGELOG.md` dosyasında tutulur.

## 1. Kod ve paket — tamamlandı

- [x] Marketing version `1.1.0`, build `4`.
- [x] Free/Pro erişim matrisi kod ve mağaza metninde eşleştirildi.
- [x] iOS Simulator: 305/305 test geçti, 0 skipped, 0 failure.
- [x] Release yapılandırması imzasız Simulator hedefinde derlendi.
- [x] AI proxy TypeScript `--noEmit` kontrolü geçti.
- [x] npm audit: 0 bilinen açık.
- [x] `git diff --check` temiz.

## 2. Supabase — canlı işlem gerekli

- [ ] Önce canlı veritabanı yedeği/snapshot doğrulansın.
- [ ] SQL Editor'da `docs/SUPABASE_SECURITY_HARDENING_1_1.sql` çalıştırılsın.
- [ ] Normal authenticated kullanıcıyla `role='admin'` insert denemesi reddedilsin.
- [ ] Normal kullanıcıyla `is_pro=true`, `is_verified=true` ve `is_banned=false`
  güncellemeleri reddedilsin.
- [ ] Aynı kullanıcı kendi `display_name` alanını güncelleyebilsin.
- [ ] Normal kullanıcı moderation RPC çağrısında yetkisiz kalsın.
- [ ] Feed, profil düzenleme, post/yorum oluşturma ve hesap silme gerçek hesapla
  smoke test edilsin.

## 3. AI proxy — canlı işlem gerekli

- [ ] Vercel Production ortamında şu değişkenler doğrulansın:
  `DEEPSEEK_API_KEY`, `ARVIA_CLIENT_SECRET`, `ARVIA_IAP_ISSUER_ID`,
  `ARVIA_IAP_KEY_ID`, `ARVIA_IAP_PRIVATE_KEY`,
  `ARVIA_BUNDLE_ID=com.ruhsatim.app`, `UPSTASH_REDIS_REST_URL` ve
  `UPSTASH_REDIS_REST_TOKEN`.
- [ ] Global günlük tavanlar bütçeye göre açıkça ayarlansın:
  `GLOBAL_DAILY_RECEIPT_LIMIT`, `GLOBAL_DAILY_MAINTENANCE_LIMIT`.
- [ ] Önce Vercel preview dağıtımı yapılsın; geçerli Sandbox Pro işlem ID'siyle iki
  görev de test edilsin.
- [ ] Eksik/bozuk işlem ID'si 400/403, yanlış secret 401, büyük payload 413,
  kullanıcı kotası ve global kota 429 döndürsün.
- [ ] İade edilmiş lifetime işlemi ve süresi dolmuş abonelik Pro kabul edilmesin.
- [ ] Redis'te yalnızca hash'li işlem kimliğine bağlı sayaçlar bulunduğu; model
  giriş/çıkışının saklanmadığı kontrol edilsin.
- [ ] Production dağıtımı manuel App Store yayınıyla koordine edilsin.

> Önemli uyumluluk notu: 1.0.1 istemcisi `transactionId` göndermez. Sertleştirilmiş
> proxy erken dağıtılırsa mevcut 1.0.1 Pro kullanıcılarının AI çağrıları 403 alır.
> Güvenli sıra: 1.1.0 inceleme build'i mevcut proxy ile doğrulanır; sürüm manuel
> yayına hazır olduğunda yeni proxy dağıtılır ve hemen ardından 1.1.0 açılır.
> Eski sürümde AI için “güncelleme gerekli” etkisi kabul edilmelidir; güvensiz
> legacy kimlik doğrulaması yeniden açılmamalıdır.

## 4. StoreKit / cihaz smoke testi

- [ ] Aylık, yıllık ve lifetime Product ID'leri App Store Connect'te Ready to
  Submit/Approved durumunda ve kodla birebir aynı olsun.
- [ ] Temiz Free hesap: ikinci araç, gelişmiş rapor, tarama, satış PDF ve asistan
  paywall ile kapalı; belge, ekspertiz, geçmiş arama ve temel raporlar açık.
- [ ] Sandbox satın alma sonrası ekranı kapatıp açmadan Pro alanları açılsın.
- [ ] AI planı oluştururken `AppStore.sync()` veya Apple parola ekranı açılmasın;
  etkin StoreKit 2 işlem ID'si Apple Server API üzerinden doğrulansın.
- [ ] Restore Purchases yeni kurulumda Pro erişimini geri getirsin.
- [ ] Süresi dolan/iptal edilen abonelik ve refund edilmiş lifetime Pro'yu kapatsın.
- [ ] Bitiş tarihli belge ekleme/düzenleme/silme bağlı hatırlatıcıyı yinelenmeden
  oluştursun, güncellesin ve temizlesin.
- [ ] iCloud açık iki cihazda örnek araç, belge, hatırlatıcı ve fotoğraf senkronu;
  iCloud kullanılamadığında yerel fallback açılışı doğrulansın.

## 5. App Store ve yasal yüzeyler

- [ ] `Resources/AppStoreMetadata.md` içindeki What's New ve Review Notes girilsin.
- [ ] Yeni Free rapor, geçmiş arama ve belge hatırlatıcısı ekran görüntüleri
  gözden geçirilsin; Pro görselinde belgeyi kilitli gösteren eski metin kullanılmasın.
- [ ] App Privacy cevapları `docs/PRIVACY_LABELS_RECONCILIATION.md` ile eşleştirilsin.
- [ ] Güncel privacy/terms/support sayfaları yayınlanıp App Store URL'lerinden
  erişilebilirliği kontrol edilsin.
- [ ] Archive validation, gerçek cihaz smoke testi ve TestFlight Internal tamamlanınca
  manuel release seçeneğiyle incelemeye gönderilsin.

## Go / No-Go

Supabase yetki testleri, gerçek StoreKit makbuz testleri veya proxy production
smoke testi tamamlanmadan sürüm **Go** sayılmaz. Kritik kapıda hata varsa geri
dönüş, uygulama binary'sini geri almak yerine proxy dağıtımını önceki güvenli
deployment'a çevirmek ve App Store manuel release'i kapalı tutmaktır.
