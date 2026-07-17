# Arvia 1.1.0 — Ürün Paketi

## Hedef

1.0.1'in güvenlik ve veri bütünlüğü tabanını koruyarak günlük kullanım değerini
artırmak; Free kullanıcıya ürünün temel faydasını göstermek ve Pro değerini
"veriyi saklamak" yerine "veriyi anlamlandırmak" üzerinden netleştirmek.

## Paket kapsamı

### 1. Temel Raporlar — Free

- Seçilen yıl ve araç için toplam masraf.
- İçinde bulunulan ayın masrafı ve kayıt sayısı.
- Araç/yıl filtreleri.
- Boş durumda doğrudan masraf ekleme akışı.

### 2. Gelişmiş Analiz — Pro

- Kilometre başı maliyet (yalnızca en az iki güvenilir km okuması varsa).
- Yıllık karşılaştırma, aylık grafik ve kategori dağılımı.
- En masraflı ay ve en yüksek giderler.
- Satış dosyasına hızlı geçiş.

Free ekranında temel rapor kapatılmaz; gelişmiş bölüm açıklamalı ve tek bir Pro
çağrısıyla kilitlenir.

### 3. Geçmişte Arama — Free

- Masraf, bakım, belge, ekspertiz ve tamamlanan işlerde metin arama.
- Firma, kategori, belge adı, plaka ve not alanları aranabilir.
- Eski 50 kayıtlık görünmez kesme kaldırılır.
- Arama sonucu yoksa filtreleri bozmadan açıklayıcı boş durum gösterilir.

### 4. Belge Bitiş Tarihi Hatırlatıcısı — Free

- Bitiş tarihi girilen belge için isteğe bağlı otomatik hatırlatıcı.
- Trafik sigortası, kasko, muayene ve garanti türleri uygun hatırlatıcı
  şablonuna eşlenir; diğer belgeler genel hatırlatıcı kullanır.
- Belge düzenlendiğinde bağlı hatırlatıcı güncellenir.
- Seçenek kapatılırsa veya belge silinirse yalnızca otomatik oluşturulan bağlı
  hatırlatıcı kaldırılır.
- Belge ve hatırlatıcı tek SwiftData işlemi olarak kaydedilir.

## Free / Pro matrisi

| Alan | Free | Pro |
|---|---:|---:|
| Tek araç | Evet | Evet |
| Ek araç | Hayır | Evet |
| Belge ve bitiş hatırlatıcısı | Evet | Evet |
| Ekspertiz kaydı | Evet | Evet |
| Geçmiş ve arama | Evet | Evet |
| Temel yıllık/aylık masraf özeti | Evet | Evet |
| Grafikler, trendler, kategori ve km maliyeti | Hayır | Evet |
| Fiş/fatura tarama | Hayır | Evet |
| Satış dosyası PDF | Hayır | Evet |
| Akıllı Sürüş Asistanı | Hayır | Evet |

## Yayın kabul kriterleri

- Tüm mevcut ve yeni testler başarılı.
- Free kullanıcı temel raporları görebilir fakat gelişmiş analizlere erişemez.
- Pro satın alma/geri yükleme sonrası ekran yeniden açılmadan gelişmiş raporlar
  görünür.
- Otomatik belge hatırlatıcısı yinelenmez ve belgeyle birlikte temizlenir.
- App Store sürümü `1.1.0`, build numarası `4` olur.
- Canlı Supabase migration ve AI proxy dağıtımı yayın kontrol listesinde zorunlu
  kapı olarak kalır.
