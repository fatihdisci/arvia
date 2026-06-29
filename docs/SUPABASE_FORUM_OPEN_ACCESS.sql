-- ============================================================================
-- Arvia — Forum Open Access Migration (Final)
-- ============================================================================
-- Supabase SQL Editor'da çalıştırın. Idempotent'tir — tekrar çalıştırılabilir.
--
-- Değişiklikler:
--   1. SELECT policy'leri: anon dahil herkes okuyabilir (auth.uid() IS NOT NULL kaldırıldı)
--   2. INSERT policy'leri: profiles.is_pro = true şartı kaldırıldı
--   3. INSERT için: auth.uid() IS NOT NULL, author_id = auth.uid(), is_banned = false
--   4. UPDATE/DELETE: owner/admin/mod güvenliği korunur
--   5. Admin/mod: hidden/deleted içerikleri görebilir ve modere edebilir
--   6. Banned: okuyabilir, yazamaz/etkileşemez
--
-- Forum erişim matrisi:
--   | Kullanıcı          | Okuma | Yazma | Etkileşim |
--   |--------------------|-------|-------|-----------|
--   | Guest (anon)       | ✅    | ❌    | ❌        |
--   | Signed-in Free     | ✅    | ✅    | ✅        |
--   | Signed-in Pro      | ✅    | ✅    | ✅        |
--   | Admin/mod          | ✅    | ✅    | ✅        |
--   | Banned             | ✅    | ❌    | ❌        |
-- ============================================================================

-- ============================================================================
-- 1. PROFILES
-- ============================================================================

DROP POLICY IF EXISTS "Profiles_are_public" ON profiles;
DROP POLICY IF EXISTS "Authenticated_can_read_profiles" ON profiles;
DROP POLICY IF EXISTS "Users_can_insert_own_profile" ON profiles;
DROP POLICY IF EXISTS "Users_can_update_own_profile" ON profiles;

-- Herkes tüm profilleri okuyabilir (anon dahil)
CREATE POLICY "Profiles_are_public" ON profiles
  FOR SELECT USING (true);

-- Kullanıcı kendi profilini oluşturabilir (banned bile olsa — ilk profil)
CREATE POLICY "Users_can_insert_own_profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Kullanıcı kendi profilini güncelleyebilir (banned değilse)
CREATE POLICY "Users_can_update_own_profile" ON profiles
  FOR UPDATE USING (
    auth.uid() = id
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND is_banned = false
    )
  );

-- ============================================================================
-- 2. COMMUNITY POSTS — SELECT
-- Anon dahil herkes okuyabilir. Hidden/deleted sadece admin/mod.
-- ============================================================================

DROP POLICY IF EXISTS "Visible_non_deleted_posts" ON community_posts;
DROP POLICY IF EXISTS "Authenticated_can_read_posts" ON community_posts;

CREATE POLICY "Visible_non_deleted_posts" ON community_posts
  FOR SELECT USING (
    deleted_at IS NULL
    AND (
      is_hidden = false
      OR auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
    )
  );

-- ============================================================================
-- 3. COMMUNITY POSTS — INSERT
-- Auth yeterli. Pro şartı yok. Banned yazamaz.
-- ============================================================================

DROP POLICY IF EXISTS "Pro_or_admin_can_create_posts" ON community_posts;
DROP POLICY IF EXISTS "Authenticated_can_create_posts" ON community_posts;

CREATE POLICY "Authenticated_can_create_posts" ON community_posts
  FOR INSERT WITH CHECK (
    author_id = auth.uid()
    AND auth.uid() IN (
      SELECT id FROM profiles
      WHERE is_banned = false
    )
  );

-- ============================================================================
-- 4. COMMUNITY POSTS — UPDATE
-- Yazar: kendi postunu güncelleyebilir (banned değilse, silinmemişse)
-- Admin/mod: tüm postları güncelleyebilir (hide, pin, soft-delete)
-- ============================================================================

DROP POLICY IF EXISTS "Author_can_update_own_post" ON community_posts;
DROP POLICY IF EXISTS "Admin_can_update_any_post" ON community_posts;
DROP POLICY IF EXISTS "Author_can_soft_delete_own_post" ON community_posts;

-- Yazar: kendi postunu düzenle
CREATE POLICY "Author_can_update_own_post" ON community_posts
  FOR UPDATE USING (
    auth.uid() = author_id
    AND deleted_at IS NULL
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND is_banned = false
    )
  );

-- Admin/moderator: tüm postları güncelleyebilir
CREATE POLICY "Admin_can_update_any_post" ON community_posts
  FOR UPDATE USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
  );

-- ============================================================================
-- 5. COMMUNITY POSTS — DELETE (Hard delete — sadece admin/mod)
-- ============================================================================

DROP POLICY IF EXISTS "Admin_can_hard_delete_posts" ON community_posts;

CREATE POLICY "Admin_can_hard_delete_posts" ON community_posts
  FOR DELETE USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
  );

-- ============================================================================
-- 6. COMMUNITY COMMENTS — SELECT
-- Anon dahil herkes okuyabilir. Hidden/deleted sadece admin/mod.
-- ============================================================================

DROP POLICY IF EXISTS "Visible_non_deleted_comments" ON community_comments;
DROP POLICY IF EXISTS "Authenticated_can_read_comments" ON community_comments;

CREATE POLICY "Visible_non_deleted_comments" ON community_comments
  FOR SELECT USING (
    deleted_at IS NULL
    AND (
      is_hidden = false
      OR auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
    )
  );

-- ============================================================================
-- 7. COMMUNITY COMMENTS — INSERT
-- Auth yeterli. Pro şartı yok. Banned yazamaz.
-- ============================================================================

DROP POLICY IF EXISTS "Pro_or_admin_can_create_comments" ON community_comments;
DROP POLICY IF EXISTS "Authenticated_can_create_comments" ON community_comments;

CREATE POLICY "Authenticated_can_create_comments" ON community_comments
  FOR INSERT WITH CHECK (
    author_id = auth.uid()
    AND auth.uid() IN (
      SELECT id FROM profiles
      WHERE is_banned = false
    )
  );

-- ============================================================================
-- 8. COMMUNITY COMMENTS — UPDATE
-- Yazar: kendi yorumunu güncelleyebilir (banned değilse, silinmemişse)
-- Admin/mod: tüm yorumları güncelleyebilir
-- ============================================================================

DROP POLICY IF EXISTS "Author_can_update_own_comment" ON community_comments;
DROP POLICY IF EXISTS "Admin_can_update_any_comment" ON community_comments;

CREATE POLICY "Author_can_update_own_comment" ON community_comments
  FOR UPDATE USING (
    auth.uid() = author_id
    AND deleted_at IS NULL
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND is_banned = false
    )
  );

CREATE POLICY "Admin_can_update_any_comment" ON community_comments
  FOR UPDATE USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
  );

-- ============================================================================
-- 9. COMMUNITY COMMENTS — DELETE (Hard delete — sadece admin/mod)
-- ============================================================================

DROP POLICY IF EXISTS "Admin_can_hard_delete_comments" ON community_comments;

CREATE POLICY "Admin_can_hard_delete_comments" ON community_comments
  FOR DELETE USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
  );

-- ============================================================================
-- 10. LIKES
-- ============================================================================

DROP POLICY IF EXISTS "Likes_are_public" ON community_post_likes;
DROP POLICY IF EXISTS "Users_can_like" ON community_post_likes;
DROP POLICY IF EXISTS "Users_can_unlike" ON community_post_likes;

CREATE POLICY "Likes_are_public" ON community_post_likes
  FOR SELECT USING (true);

CREATE POLICY "Users_can_like" ON community_post_likes
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND is_banned = false
    )
  );

CREATE POLICY "Users_can_unlike" ON community_post_likes
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- 11. SAVES
-- ============================================================================

DROP POLICY IF EXISTS "Saves_are_public" ON community_post_saves;
DROP POLICY IF EXISTS "Users_can_save" ON community_post_saves;
DROP POLICY IF EXISTS "Users_can_unsave" ON community_post_saves;

CREATE POLICY "Saves_are_public" ON community_post_saves
  FOR SELECT USING (true);

CREATE POLICY "Users_can_save" ON community_post_saves
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND is_banned = false
    )
  );

CREATE POLICY "Users_can_unsave" ON community_post_saves
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- 12. REPORTS
-- ============================================================================

DROP POLICY IF EXISTS "Users_can_create_reports" ON community_reports;
DROP POLICY IF EXISTS "Admins_can_view_reports" ON community_reports;
DROP POLICY IF EXISTS "Admins_can_update_reports" ON community_reports;

CREATE POLICY "Users_can_create_reports" ON community_reports
  FOR INSERT WITH CHECK (
    auth.uid() = reporter_id
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND is_banned = false
    )
  );

CREATE POLICY "Admins_can_view_reports" ON community_reports
  FOR SELECT USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
  );

CREATE POLICY "Admins_can_update_reports" ON community_reports
  FOR UPDATE USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
  );

-- ============================================================================
-- 13. BLOCKS
-- ============================================================================

DROP POLICY IF EXISTS "Users_can_view_own_blocks" ON community_blocks;
DROP POLICY IF EXISTS "Users_can_block" ON community_blocks;
DROP POLICY IF EXISTS "Users_can_unblock" ON community_blocks;

CREATE POLICY "Users_can_view_own_blocks" ON community_blocks
  FOR SELECT USING (
    auth.uid() = blocker_id
    OR auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
  );

CREATE POLICY "Users_can_block" ON community_blocks
  FOR INSERT WITH CHECK (
    auth.uid() = blocker_id
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND is_banned = false
    )
  );

CREATE POLICY "Users_can_unblock" ON community_blocks
  FOR DELETE USING (auth.uid() = blocker_id);

-- ============================================================================
-- DOĞRULAMA
-- ============================================================================

-- 1. Tüm policy'leri listele:
-- SELECT tablename, policyname, cmd FROM pg_policies
-- WHERE tablename LIKE 'community_%' OR tablename = 'profiles'
-- ORDER BY tablename, cmd;

-- 2. Test: Anon istek ile gönderi okumayı dene → BAŞARILI olmalı.
--    curl 'https://fxltjhenpjydbsjtgpsi.supabase.co/rest/v1/community_posts?select=*&limit=1'
--    Cevap: [{...}] — gönderi verisi dönmeli

-- 3. Test: Auth header ile INSERT dene (Free kullanıcı) → BAŞARILI olmalı.
--    curl -X POST -H 'Authorization: Bearer <JWT>' \
--      -H 'Content-Type: application/json' \
--      -d '{"author_id":"<USER_ID>","title":"Test","body":"Test","post_type":"discussion","tags":["genel"]}' \
--      'https://fxltjhenpjydbsjtgpsi.supabase.co/rest/v1/community_posts'
--    Cevap: 201 Created

-- 4. Test: Banned kullanıcı INSERT denesin → RLS hatası almalı.
--    Cevap: {"code":"42501","message":"new row violates row-level security policy"}

-- 5. Test: Anon INSERT denesin → auth hatası almalı.
--    curl -X POST -H 'Content-Type: application/json' \
--      -d '{"author_id":"...","title":"Anon","body":"Test","post_type":"discussion","tags":["genel"]}' \
--      'https://fxltjhenpjydbsjtgpsi.supabase.co/rest/v1/community_posts'
--    Cevap: {"code":"PGRST301","message":"No authorization header"}
-- ============================================================================
