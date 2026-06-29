-- ============================================================================
-- Arvia — Moderation System Fixes (Idempotent)
-- ============================================================================
-- Supabase SQL Editor'da çalıştırın. Idempotent'tir — tekrar çalıştırılabilir.
--
-- Değişiklikler:
--   1. community_reports — DELETE policy eklendi (admin/moderator only)
--      (Daha önce community_reports tablosunda DELETE policy yoktu —
--       admin/mod eski raporları temizleyemiyordu.)
--   2. community_reports — reporter kendi raporunu görebilsin policy'si eklendi
--      (Kullanıcı yaptığı bildirimin durumunu takip edebilir.)
--
-- Yetkili RLS dosyası: SUPABASE_FORUM_OPEN_ACCESS.sql
-- SUPABASE_RLS_ANON_FIX.sql ve SUPABASE_RLS_FIX.sql artık geçerli değil —
--   deprecation notları ilgili dosyalara eklenmiştir.
-- ============================================================================

-- 1. COMMUNITY REPORTS — DELETE (admin/mod only)
DROP POLICY IF EXISTS "Admins_can_delete_reports" ON community_reports;

CREATE POLICY "Admins_can_delete_reports" ON community_reports
  FOR DELETE USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
  );

-- 2. COMMUNITY REPORTS — SELECT (reporter kendi raporunu görebilir)
DROP POLICY IF EXISTS "Reporters_can_view_own_reports" ON community_reports;

CREATE POLICY "Reporters_can_view_own_reports" ON community_reports
  FOR SELECT USING (
    auth.uid() = reporter_id
  );

-- ============================================================================
-- DOĞRULAMA
-- ============================================================================

-- 1. Tüm community_reports policy'lerini listele:
-- SELECT tablename, policyname, cmd FROM pg_policies
-- WHERE tablename = 'community_reports'
-- ORDER BY cmd;

-- Beklenen sonuç (5 policy):
--   community_reports | Users_can_create_reports       | INSERT
--   community_reports | Admins_can_view_reports        | SELECT
--   community_reports | Reporters_can_view_own_reports | SELECT
--   community_reports | Admins_can_update_reports      | UPDATE
--   community_reports | Admins_can_delete_reports      | DELETE

-- 2. Test: Admin JWT ile community_reports DELETE dene → 200 OK
--    curl -X DELETE -H 'Authorization: Bearer <ADMIN_JWT>' \
--      'https://fxltjhenpjydbsjtgpsi.supabase.co/rest/v1/community_reports?id=eq.<REPORT_ID>'

-- 3. Test: Normal kullanıcı JWT ile community_reports DELETE dene → RLS hatası
--    curl -X DELETE -H 'Authorization: Bearer <USER_JWT>' \
--      'https://fxltjhenpjydbsjtgpsi.supabase.co/rest/v1/community_reports?id=eq.<REPORT_ID>'
--    Cevap: {"code":"42501","message":"new row violates row-level security policy"}

-- 4. Test: Kullanıcı kendi raporunu görebilmeli
--    curl -H 'Authorization: Bearer <USER_JWT>' \
--      'https://fxltjhenpjydbsjtgpsi.supabase.co/rest/v1/community_reports?select=*'
--    Cevap: Sadece kendi reporter_id'li raporlar dönmeli
-- ============================================================================
