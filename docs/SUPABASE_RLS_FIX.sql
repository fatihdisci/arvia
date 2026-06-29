-- ⚠️ BU DOSYA ARTIK GEÇERLİ DEĞİL.
-- Yetkili dosya: SUPABASE_FORUM_OPEN_ACCESS.sql
-- Satır 290'a yakın doğrulama notu HATALIDIR:
--   "Free kullanıcı INSERT yapabilir mi? (cevap: HAYIR)" → cevap EVET.
--   Free kullanıcı INSERT yapabilir; forum yazma Pro gerektirmez.
-- ============================================================================
-- Garajım — Topluluk RLS Fix / Migration (DEPRECATED)
-- ============================================================================
-- Supabase SQL Editor'da çalıştırın. Idempotent'tir (tekrar çalıştırılabilir).
--
-- Düzeltilen eksikler:
--   1. community_posts — admin/moderator hard DELETE policy'si EKLENDİ
--   2. community_comments — admin/moderator hard DELETE policy'si EKLENDİ
--   3. likes/saves — banned kullanıcı INSERT engeli EKLENDİ
--   4. community_posts UPDATE — banned kontrolü EKLENDİ
--   5. Tüm INSERT policy'lere `author_id = auth.uid()` kontrolü EKLENDİ
--   6. reports INSERT — banned kontrolü EKLENDİ
--
-- Mevcut doğru policy'ler: DROP EDİLİP YENİDEN OLUŞTURULUR.
-- ============================================================================

-- ============================================================================
-- 1. PROFILES
-- ============================================================================

DROP POLICY IF EXISTS "Profiles_are_public" ON profiles;
DROP POLICY IF EXISTS "Users_can_insert_own_profile" ON profiles;
DROP POLICY IF EXISTS "Users_can_update_own_profile" ON profiles;

-- Herkes tüm profilleri okuyabilir
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
-- ============================================================================

DROP POLICY IF EXISTS "Visible_non_deleted_posts" ON community_posts;

-- Herkes silinmemiş ve gizli olmayan gönderileri görebilir.
-- Admin/moderator gizli gönderileri de görebilir.
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
-- Kural: auth.uid() mevcut, profiles.is_banned = false
--        VE author_id = auth.uid() (başkası adına post atılamaz)
-- Forum yazma Pro gerektirmez — auth yeterlidir.
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
-- Yazar: kendi gizli/silinmemiş postunu güncelleyebilir (banned değilse)
-- Admin/moderator: tüm postları güncelleyebilir (hide, pin, soft-delete)
-- ============================================================================

DROP POLICY IF EXISTS "Author_can_update_own_post" ON community_posts;
DROP POLICY IF EXISTS "Admin_can_update_any_post" ON community_posts;
DROP POLICY IF EXISTS "Author_can_soft_delete_own_post" ON community_posts;

-- Yazar: kendi postunu düzenle (banned değilse)
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
-- 5. COMMUNITY POSTS — DELETE (Hard delete — sadece admin)
-- ============================================================================

DROP POLICY IF EXISTS "Admin_can_hard_delete_posts" ON community_posts;

CREATE POLICY "Admin_can_hard_delete_posts" ON community_posts
  FOR DELETE USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
  );

-- ============================================================================
-- 6. COMMUNITY COMMENTS — SELECT
-- ============================================================================

DROP POLICY IF EXISTS "Visible_non_deleted_comments" ON community_comments;

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
-- Kural: auth.uid() mevcut, profiles.is_banned = false
-- Yorum yazma Pro gerektirmez — auth yeterlidir.
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
-- Yazar: kendi yorumunu güncelleyebilir (banned değilse)
-- Admin/moderator: tüm yorumları güncelleyebilir
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
-- 9. COMMUNITY COMMENTS — DELETE (Hard delete — admin only)
-- ============================================================================

DROP POLICY IF EXISTS "Admin_can_hard_delete_comments" ON community_comments;

CREATE POLICY "Admin_can_hard_delete_comments" ON community_comments
  FOR DELETE USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
  );

-- ============================================================================
-- 10. LIKES — banned kullanıcı beğenemez
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
-- 11. SAVES — banned kullanıcı kaydedemez
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
-- 12. REPORTS — banned kullanıcı bildirim yapamaz
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
-- 13. BLOCKS — banned kullanıcı engelleme yapamaz
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
-- DOĞRULAMA SORGULARI
-- ============================================================================

-- Policy'lerin oluştuğunu kontrol et:
-- SELECT tablename, policyname, cmd FROM pg_policies
-- WHERE tablename LIKE 'community_%' OR tablename = 'profiles'
-- ORDER BY tablename, cmd;

-- Test: Free kullanıcı INSERT yapabilir mi? (cevap: EVET — forum auth-gated, Pro gerektirmez)
-- 1. Supabase Dashboard → Authentication → kendinize test kullanıcısı oluşturun
-- 2. profiles tablosuna o kullanıcı için is_pro=false, is_banned=false kayıt ekleyin
-- 3. O kullanıcı ile giriş yapıp community_posts insert deneyin
-- 4. BAŞARILI olmalı: 201 Created

-- ============================================================================
