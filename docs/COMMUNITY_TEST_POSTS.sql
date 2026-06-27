-- ============================================================================
-- Garajım — Topluluk Test Gönderileri SQL
-- ============================================================================
-- Tarih: 27 Haziran 2026
-- KULLANIM: Supabase Dashboard → SQL Editor → bu dosyayı yapıştır → Run
-- ============================================================================

-- 1. Test kullanıcısı için profil oluştur (yoksa)
INSERT INTO profiles (id, username, display_name, role, is_verified, is_pro)
VALUES (
  '4c7cf39a-c699-49e4-866a-241c0e288638',
  'fatih_test',
  'Fatih',
  'admin',
  true,
  true
)
ON CONFLICT (id) DO UPDATE SET
  role = 'admin',
  is_verified = true,
  is_pro = true,
  display_name = 'Fatih',
  username = 'fatih_test';

-- 2. Test gönderisi 1 — Duyuru (pinned)
INSERT INTO community_posts (
  id,
  author_id,
  title,
  body,
  post_type,
  tags,
  is_pinned,
  is_hidden,
  like_count,
  comment_count,
  save_count
) VALUES (
  uuid_generate_v4(),
  '4c7cf39a-c699-49e4-866a-241c0e288638',
  'Topluluğa hoş geldiniz! 🚗',
  'Garajım topluluğu yayında! Burada araç bakımı, masraf yönetimi, motosiklet ipuçları ve daha fazlası hakkında paylaşımlar yapabilirsiniz. Deneyimlerinizi paylaşmaktan çekinmeyin. Kurallar sayfasını okumayı unutmayın.',
  'announcement',
  ARRAY['Genel', 'Duyuru'],
  true,
  false,
  5,
  2,
  3
);

-- 3. Test gönderisi 2 — Deneyim (normal post)
INSERT INTO community_posts (
  id,
  author_id,
  title,
  body,
  post_type,
  tags,
  vehicle_brand,
  vehicle_model,
  vehicle_year,
  is_pinned,
  is_hidden,
  like_count,
  save_count
) VALUES (
  uuid_generate_v4(),
  '4c7cf39a-c699-49e4-866a-241c0e288638',
  'Toyota Corolla Hybrid 2 yıllık kullanım deneyimim',
  'Merhaba arkadaşlar, 2022 model Toyota Corolla 1.8 Hybrid aracımı 2 yıldır kullanıyorum ve deneyimlerimi paylaşmak istedim. Şehir içinde ortalama 4.5L/100km yakıt tüketimi ile gerçekten çok ekonomik. CVT şanzıman başta alışması zor olsa da zamanla çok keyifli hale geliyor. Bakım maliyetleri benzinli araçlara göre daha uygun. Tek dezavantajı bagaj hacminin biraz küçük olması. Sorularınız varsa cevaplamaktan mutluluk duyarım!',
  'experience',
  ARRAY['Deneyim', 'Hibrit', 'Yakıt'],
  'Toyota',
  'Corolla',
  2022,
  false,
  false,
  8,
  6
);
