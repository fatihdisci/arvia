# Changelog

Bu projedeki önemli ürün ve teknik değişiklikler bu dosyada tutulur.

## 1.1.0 — 2026-07-17

### Yeni

- Free kullanıcılar için araç/yıl filtreli temel yıllık ve aylık masraf özeti.
- Tüm kayıt türlerini kapsayan geçmiş araması; eski 50 kayıt sınırı kaldırıldı.
- Belge bitiş tarihiyle birlikte oluşturulup güncellenen isteğe bağlı hatırlatıcı.
- Pro kullanıcılar için gelişmiş raporlar, trendler, kategori analizi ve güvenilir
  kilometre verisine dayalı kilometre başı maliyet.
- Özel CloudKit veritabanı senkronizasyonu ve başarısız açılışlarda veri kaybını
  önleyen yerel depo fallback'i.

### Düzeltildi

- Free/Pro kontrolleri tek yetki kaynağı altında toplandı; kilitli özelliklerin
  alternatif ekranlardan açılabilmesi engellendi.
- StoreKit hakları etkin işlemlerden yeniden hesaplanarak süresi dolan veya geri
  alınan satın almaların Pro erişimini açık bırakması önlendi.
- Kilometre başı maliyetin toplam kilometreye bölünmesi yerine gerçek kayıt aralığı
  üzerinden hesaplanması sağlandı.
- Belge, fiş, araç fotoğrafı, veri dışa aktarma ve silme işlemlerinde atomiklik,
  rollback ve yetim dosya temizliği güçlendirildi.
- Hatırlatıcı tamamlama, arşivleme, silme ve bildirim yenileme akışlarındaki veri
  bütünlüğü sorunları giderildi.
- Veri dışa aktarma formatı belge kaynaklı hatırlatıcı ilişkisini içerecek şekilde
  sürüm 3'e yükseltildi.

### Güvenlik

- Supabase profil alanlarında rol/Pro/yasaklı/doğrulanmış değerlerinin istemci
  tarafından yükseltilebildiği yetki açığı kapatıldı; RLS ve kolon izinleri
  sertleştirildi.
- Topluluk istemcisinin hassas profil yetkileri yazması kaldırıldı.
- Akıllı Sürüş Asistanı kotası App Store makbuz doğrulamasına ve doğrulanmış satın
  alma kimliğine bağlandı; sahte istemci kimliğiyle kota aşımı kapatıldı.
- AI proxy giriş boyutları, ortam değişkenleri ve global/kullanıcı kotaları için
  güvenli sınırlar eklendi; hassas model yanıtı cache'i kaldırıldı.
- Hesap silme, yerel veri temizleme ve dışa aktarma akışlarının kapsamı genişletildi.

### Ürün erişimi

- Free: tek araç, belgeler ve belge hatırlatıcıları, ekspertiz, geçmiş arama ve temel
  masraf özetleri.
- Pro: ek araçlar, gelişmiş analizler, fiş/fatura tarama, satış dosyası PDF ve
  Akıllı Sürüş Asistanı.

### Yayın notu

- Uygulama sürümü `1.1.0`, build numarası `4`.
- Canlıya çıkmadan önce Supabase migration, Vercel proxy ortam değişkenleri/dağıtımı,
  gerçek App Store makbuz senaryoları ve yayınlanan gizlilik sayfaları ayrıca
  doğrulanmalıdır.
