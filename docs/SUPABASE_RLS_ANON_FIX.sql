-- ⚠️ BU DOSYA ARTIK GEÇERLİ DEĞİL.
-- Anon okuma açık kalacak şekilde karar değişti.
-- Bu dosya anon okumayı KAPATIR — tersi karar verildi.
-- Yetkili dosya: SUPABASE_FORUM_OPEN_ACCESS.sql
-- ============================================================================
-- Arvia — Topluluk RLS Anonymous Okuma Kapatma Migration (DEPRECATED)
-- ============================================================================
-- Supabase SQL Editor'da çalıştırın. Idempotent'tir.
--
-- Sorun: Mevcut post/comment SELECT policy'leri auth.uid() kontrolü
--        yapmadığı için misafir/anon kullanıcılar Supabase API üzerinden
--        forum gönderilerini okuyabiliyordu.
-- Çözüm: SELECT policy'lere `auth.uid() IS NOT NULL` ekleyerek sadece
--        Apple ile giriş yapmış kullanıcıların okumasına izin ver.
-- NOT: Bu karar DEĞİŞTİ. Anon okuma AÇIK kaldı. Bu SQL'i production'da çalıştırmayın.
-- ============================================================================

-- ============================================================================
-- 1. COMMUNITY POSTS — SELECT (anon okuma kapatma)
-- ============================================================================

DROP POLICY IF EXISTS "Visible_non_deleted_posts" ON community_posts;
DROP POLICY IF EXISTS "Authenticated_can_read_posts" ON community_posts;

-- SADECE giriş yapmış kullanıcılar okuyabilir.
-- Admin/moderator gizli gönderileri de görebilir.
CREATE POLICY "Authenticated_can_read_posts" ON community_posts
  FOR SELECT USING (
    auth.uid() IS NOT NULL
    AND deleted_at IS NULL
    AND (
      is_hidden = false
      OR auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
    )
  );

-- ============================================================================
-- 2. COMMUNITY COMMENTS — SELECT (anon okuma kapatma)
-- ============================================================================

DROP POLICY IF EXISTS "Visible_non_deleted_comments" ON community_comments;
DROP POLICY IF EXISTS "Authenticated_can_read_comments" ON community_comments;

CREATE POLICY "Authenticated_can_read_comments" ON community_comments
  FOR SELECT USING (
    auth.uid() IS NOT NULL
    AND deleted_at IS NULL
    AND (
      is_hidden = false
      OR auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
    )
  );

-- ============================================================================
-- 3. PROFILES — SELECT (anon okuma kapatma, community ile uyumlu)
-- ============================================================================

DROP POLICY IF EXISTS "Profiles_are_public" ON profiles;
DROP POLICY IF EXISTS "Authenticated_can_read_profiles" ON profiles;

-- Profil bilgilerini sadece giriş yapmış kullanıcılar görebilir.
CREATE POLICY "Authenticated_can_read_profiles" ON profiles
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- ============================================================================
-- DOĞRULAMA
-- ============================================================================

-- 1. Policy'lerin güncellendiğini kontrol et:
-- SELECT tablename, policyname, cmd, qual FROM pg_policies
-- WHERE tablename IN ('community_posts', 'community_comments', 'profiles') AND cmd = 'SELECT'
-- ORDER BY tablename;

-- 2. Test: Anon istek ile gönderi okumayı dene → hata almalısın.
--    curl 'https://fxltjhenpjydbsjtgpsi.supabase.co/rest/v1/community_posts?select=*'
--    Cevap: {"code":"PGRST301","details":null,"hint":null,"message":"No authorization header"}

-- 3. Auth header ile dene → başarılı olmalı.
--    curl -H 'Authorization: Bearer <JWT>' 'https://fxltjhenpjydbsjtgpsi.supabase.co/rest/v1/community_posts?select=*'
-- ============================================================================
