# Arvia Test Seed

Bu dosya Supabase tarafinda test verilerini temizleyip yeniden kurmak icin hazirlandi.

Not:
- `profiles` ve `community_*` tablolarini seed eder.
- Uygulamadaki gercek arac kayitlari local SwiftData'da tutuldugu icin SQL ile dogrudan araca ait satir eklenemez.
- Bu nedenle asagidaki seed, 2 arac temali topluluk icerigi ve moderator profilini olusturur.

```sql
BEGIN;

-- ============================================================================
-- 1) ESKI TEST VERILERINI TEMIZLE
-- ============================================================================

DELETE FROM community_post_likes;
DELETE FROM community_post_saves;
DELETE FROM community_reports;
DELETE FROM community_blocks;
DELETE FROM community_comments;
DELETE FROM community_posts;
DELETE FROM profiles
WHERE id = '4c7cf39a-c699-49e4-866a-241c0e288638'
   OR username = 'arvia_moderator';

-- ============================================================================
-- 2) PROFIL: ARVIA MODERATOR
-- ============================================================================

INSERT INTO profiles (
  id,
  username,
  display_name,
  avatar_url,
  role,
  is_verified,
  is_banned,
  is_pro,
  default_vehicle_brand,
  default_vehicle_model,
  default_vehicle_year,
  show_vehicle_on_posts
) VALUES (
  '4c7cf39a-c699-49e4-866a-241c0e288638',
  'arvia_moderator',
  'Arvia Moderatör',
  NULL,
  'moderator',
  true,
  false,
  true,
  'Toyota',
  'Corolla',
  2020,
  true
)
ON CONFLICT (id) DO UPDATE SET
  username = EXCLUDED.username,
  display_name = EXCLUDED.display_name,
  avatar_url = EXCLUDED.avatar_url,
  role = EXCLUDED.role,
  is_verified = EXCLUDED.is_verified,
  is_banned = EXCLUDED.is_banned,
  is_pro = EXCLUDED.is_pro,
  default_vehicle_brand = EXCLUDED.default_vehicle_brand,
  default_vehicle_model = EXCLUDED.default_vehicle_model,
  default_vehicle_year = EXCLUDED.default_vehicle_year,
  show_vehicle_on_posts = EXCLUDED.show_vehicle_on_posts,
  updated_at = now();

-- ============================================================================
-- 3) KULLANICIYA AIT 2 ADET ARAC TEMALI TOPLULUK ICERIGI
-- ============================================================================

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
  comment_count,
  save_count,
  created_at,
  updated_at
) VALUES (
  '11111111-1111-1111-1111-111111111111',
  '4c7cf39a-c699-49e4-866a-241c0e288638',
  'Toyota Corolla 2020 ile ilk izlenimler',
  'Test verisi olarak eklenmis bu paylasimda Toyota Corolla 2020 icin yakit tuketimi, konfor ve bakim maliyetleri konusundaki ilk izlenimleri topluyoruz. Arac kaydi, topluluktaki etiketler ve yorum akisi icin ideal bir ornek veri seti.',
  'experience',
  ARRAY['Deneyim', 'Bakim', 'Yakıt'],
  'Toyota',
  'Corolla',
  2020,
  false,
  false,
  1,
  1,
  1,
  now() - interval '2 days',
  now() - interval '2 days'
),
(
  '22222222-2222-2222-2222-222222222222',
  '4c7cf39a-c699-49e4-866a-241c0e288638',
  'Renault Clio 2018 icin bakim notlari',
  'Bu ikinci test icerigi Renault Clio 2018 uzerinden olusturuldu. Periyodik bakim, lastik, sigorta ve genel kullanim notlarini gostermek icin kullanilabilir. Topluluktaki soru-cevap ve raporlama ekranlarini test etmek icin de uygun.',
  'advice',
  ARRAY['Tavsiye', 'Bakim', 'Sigorta'],
  'Renault',
  'Clio',
  2018,
  false,
  false,
  1,
  1,
  1,
  now() - interval '1 day',
  now() - interval '1 day'
);

-- ============================================================================
-- 4) YORUMLAR
-- ============================================================================

INSERT INTO community_comments (
  id,
  post_id,
  author_id,
  body,
  is_hidden,
  created_at,
  updated_at
) VALUES (
  '33333333-3333-3333-3333-333333333333',
  '11111111-1111-1111-1111-111111111111',
  '4c7cf39a-c699-49e4-866a-241c0e288638',
  'Test yorumu: bu post arac detay karti, yorum sayaci ve zaman damgasi icin kullaniliyor.',
  false,
  now() - interval '2 days' + interval '15 minutes',
  now() - interval '2 days' + interval '15 minutes'
),
(
  '44444444-4444-4444-4444-444444444444',
  '22222222-2222-2222-2222-222222222222',
  '4c7cf39a-c699-49e4-866a-241c0e288638',
  'Ikinci test yorumu: bakim ve uyarilar ekraninda yorum akisinin dogru calistigini kontrol etmek icin.',
  false,
  now() - interval '1 day' + interval '10 minutes',
  now() - interval '1 day' + interval '10 minutes'
);

-- ============================================================================
-- 5) BEGENI VE KAYDEDILENLER
-- ============================================================================

INSERT INTO community_post_likes (post_id, user_id, created_at) VALUES
  ('11111111-1111-1111-1111-111111111111', '4c7cf39a-c699-49e4-866a-241c0e288638', now() - interval '2 days' + interval '5 minutes'),
  ('22222222-2222-2222-2222-222222222222', '4c7cf39a-c699-49e4-866a-241c0e288638', now() - interval '1 day' + interval '5 minutes');

INSERT INTO community_post_saves (post_id, user_id, created_at) VALUES
  ('11111111-1111-1111-1111-111111111111', '4c7cf39a-c699-49e4-866a-241c0e288638', now() - interval '2 days' + interval '6 minutes'),
  ('22222222-2222-2222-2222-222222222222', '4c7cf39a-c699-49e4-866a-241c0e288638', now() - interval '1 day' + interval '6 minutes');

COMMIT;
```

Istersen bir sonraki adimda ayni 2 arac icin local SwiftData tarafina uygun `DemoDataSeeder` uyumlu bir `.swift` seed dosyasi da hazirlayabilirim.
