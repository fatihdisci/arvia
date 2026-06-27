-- ============================================================================
-- Garajım — Supabase Community Final Deployment SQL
-- ============================================================================
-- Tarih: 27 Haziran 2026
--
-- KULLANIM:
--   1. Supabase Dashboard → SQL Editor
--   2. Bu dosyanın TAMAMINI yapıştır
--   3. "Run" butonuna tıkla
--
-- Bu SQL idempotent'tir — tekrar tekrar çalıştırılabilir.
-- Mevcut tablo/policy'leri bozmaz, eksikleri ekler.
-- ============================================================================

-- UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- TABLOLAR
-- ============================================================================

-- 1. Kullanıcı Profilleri (id = auth.users.id)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL
    CHECK (char_length(username) >= 3 AND char_length(username) <= 20),
  display_name TEXT
    CHECK (display_name IS NULL OR char_length(display_name) <= 50),
  avatar_url TEXT,
  role TEXT NOT NULL DEFAULT 'user'
    CHECK (role IN ('user', 'moderator', 'admin')),
  is_verified BOOLEAN NOT NULL DEFAULT false,
  is_banned BOOLEAN NOT NULL DEFAULT false,
  is_pro BOOLEAN NOT NULL DEFAULT false,
  default_vehicle_brand TEXT,
  default_vehicle_model TEXT,
  default_vehicle_year INTEGER,
  show_vehicle_on_posts BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Topluluk Gönderileri
CREATE TABLE IF NOT EXISTS community_posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id UUID NOT NULL REFERENCES profiles(id),
  title TEXT NOT NULL CHECK (char_length(title) >= 5 AND char_length(title) <= 120),
  body TEXT NOT NULL CHECK (char_length(body) >= 20 AND char_length(body) <= 5000),
  post_type TEXT NOT NULL DEFAULT 'experience'
    CHECK (post_type IN ('news', 'announcement', 'advice', 'problem', 'experience', 'question')),
  tags TEXT[] NOT NULL DEFAULT '{}',
  vehicle_brand TEXT,
  vehicle_model TEXT,
  vehicle_year INTEGER,
  is_pinned BOOLEAN NOT NULL DEFAULT false,
  is_hidden BOOLEAN NOT NULL DEFAULT false,
  like_count INTEGER NOT NULL DEFAULT 0,
  comment_count INTEGER NOT NULL DEFAULT 0,
  save_count INTEGER NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Topluluk Yorumları
CREATE TABLE IF NOT EXISTS community_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES profiles(id),
  body TEXT NOT NULL CHECK (char_length(body) >= 2 AND char_length(body) <= 1000),
  is_hidden BOOLEAN NOT NULL DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Beğeni (Like)
CREATE TABLE IF NOT EXISTS community_post_likes (
  post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

-- 5. Kaydetme (Save/Bookmark)
CREATE TABLE IF NOT EXISTS community_post_saves (
  post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

-- 6. Şikayet (Report)
CREATE TABLE IF NOT EXISTS community_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_id UUID NOT NULL REFERENCES profiles(id),
  target_type TEXT NOT NULL CHECK (target_type IN ('post', 'comment')),
  target_id UUID NOT NULL,
  reason TEXT NOT NULL
    CHECK (reason IN ('spam', 'harassment', 'misleading', 'personalInfo', 'inappropriate', 'other')),
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'reviewed', 'dismissed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at TIMESTAMPTZ,
  reviewer_id UUID REFERENCES profiles(id)
);

-- 7. Engelleme (Block)
CREATE TABLE IF NOT EXISTS community_blocks (
  blocker_id UUID NOT NULL REFERENCES profiles(id),
  blocked_id UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id)
);

-- ============================================================================
-- INDEX'LER
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_posts_author ON community_posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_created ON community_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_type ON community_posts(post_type);
CREATE INDEX IF NOT EXISTS idx_posts_not_deleted ON community_posts(deleted_at) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_comments_post ON community_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_author ON community_comments(author_id);
CREATE INDEX IF NOT EXISTS idx_comments_created ON community_comments(created_at);

CREATE INDEX IF NOT EXISTS idx_likes_post ON community_post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_likes_user ON community_post_likes(user_id);

CREATE INDEX IF NOT EXISTS idx_saves_post ON community_post_saves(post_id);
CREATE INDEX IF NOT EXISTS idx_saves_user ON community_post_saves(user_id);

CREATE INDEX IF NOT EXISTS idx_reports_status ON community_reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_target ON community_reports(target_type, target_id);

-- ============================================================================
-- TRIGGER: updated_at otomatik güncelleme
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_posts_updated_at ON community_posts;
CREATE TRIGGER update_posts_updated_at
  BEFORE UPDATE ON community_posts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_comments_updated_at ON community_comments;
CREATE TRIGGER update_comments_updated_at
  BEFORE UPDATE ON community_comments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- TRIGGER: Like/Save counter otomatik güncelleme
-- ============================================================================

-- Like counter
CREATE OR REPLACE FUNCTION update_post_like_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE community_posts SET like_count = like_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE community_posts SET like_count = like_count - 1 WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_like_count ON community_post_likes;
CREATE TRIGGER trg_like_count
  AFTER INSERT OR DELETE ON community_post_likes
  FOR EACH ROW EXECUTE FUNCTION update_post_like_count();

-- Save counter
CREATE OR REPLACE FUNCTION update_post_save_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE community_posts SET save_count = save_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE community_posts SET save_count = save_count - 1 WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_save_count ON community_post_saves;
CREATE TRIGGER trg_save_count
  AFTER INSERT OR DELETE ON community_post_saves
  FOR EACH ROW EXECUTE FUNCTION update_post_save_count();

-- Comment counter
CREATE OR REPLACE FUNCTION update_post_comment_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.deleted_at IS NULL THEN
    UPDATE community_posts SET comment_count = comment_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'UPDATE' AND OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
    UPDATE community_posts SET comment_count = comment_count - 1 WHERE id = NEW.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_comment_count ON community_comments;
CREATE TRIGGER trg_comment_count
  AFTER INSERT OR UPDATE OF deleted_at ON community_comments
  FOR EACH ROW EXECUTE FUNCTION update_post_comment_count();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) — TÜM POLİTİKALAR AKTİF
-- ============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_post_saves ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_blocks ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- PROFILES
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Profiles_are_public" ON profiles;
CREATE POLICY "Profiles_are_public" ON profiles
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users_can_insert_own_profile" ON profiles;
CREATE POLICY "Users_can_insert_own_profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users_can_update_own_profile" ON profiles;
CREATE POLICY "Users_can_update_own_profile" ON profiles
  FOR UPDATE USING (
    auth.uid() = id
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND is_banned = false
    )
  );

-- ----------------------------------------------------------------------------
-- COMMUNITY POSTS — SELECT
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Visible_non_deleted_posts" ON community_posts;
CREATE POLICY "Visible_non_deleted_posts" ON community_posts
  FOR SELECT USING (
    deleted_at IS NULL
    AND (
      is_hidden = false
      OR auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
    )
  );

-- ----------------------------------------------------------------------------
-- COMMUNITY POSTS — INSERT (Pro/admin/moderator only + banned kontrolü)
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Pro_or_admin_can_create_posts" ON community_posts;
CREATE POLICY "Pro_or_admin_can_create_posts" ON community_posts
  FOR INSERT WITH CHECK (
    author_id = auth.uid()
    AND auth.uid() IN (
      SELECT id FROM profiles
      WHERE is_banned = false
      AND (is_pro = true OR role IN ('admin', 'moderator'))
    )
  );

-- ----------------------------------------------------------------------------
-- COMMUNITY POSTS — UPDATE
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Author_can_update_own_post" ON community_posts;
CREATE POLICY "Author_can_update_own_post" ON community_posts
  FOR UPDATE USING (
    auth.uid() = author_id
    AND deleted_at IS NULL
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND is_banned = false
    )
  );

DROP POLICY IF EXISTS "Admin_can_update_any_post" ON community_posts;
CREATE POLICY "Admin_can_update_any_post" ON community_posts
  FOR UPDATE USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
  );

-- ----------------------------------------------------------------------------
-- COMMUNITY POSTS — DELETE (Hard delete — admin/moderator only)
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Admin_can_hard_delete_posts" ON community_posts;
CREATE POLICY "Admin_can_hard_delete_posts" ON community_posts
  FOR DELETE USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
  );

-- ----------------------------------------------------------------------------
-- COMMUNITY COMMENTS — SELECT
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Visible_non_deleted_comments" ON community_comments;
CREATE POLICY "Visible_non_deleted_comments" ON community_comments
  FOR SELECT USING (
    deleted_at IS NULL
    AND (
      is_hidden = false
      OR auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
    )
  );

-- ----------------------------------------------------------------------------
-- COMMUNITY COMMENTS — INSERT (Pro/admin/moderator only + banned kontrolü)
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Pro_or_admin_can_create_comments" ON community_comments;
CREATE POLICY "Pro_or_admin_can_create_comments" ON community_comments
  FOR INSERT WITH CHECK (
    author_id = auth.uid()
    AND auth.uid() IN (
      SELECT id FROM profiles
      WHERE is_banned = false
      AND (is_pro = true OR role IN ('admin', 'moderator'))
    )
  );

-- ----------------------------------------------------------------------------
-- COMMUNITY COMMENTS — UPDATE
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Author_can_update_own_comment" ON community_comments;
CREATE POLICY "Author_can_update_own_comment" ON community_comments
  FOR UPDATE USING (
    auth.uid() = author_id
    AND deleted_at IS NULL
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND is_banned = false
    )
  );

DROP POLICY IF EXISTS "Admin_can_update_any_comment" ON community_comments;
CREATE POLICY "Admin_can_update_any_comment" ON community_comments
  FOR UPDATE USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
  );

-- ----------------------------------------------------------------------------
-- COMMUNITY COMMENTS — DELETE (Hard delete — admin/moderator only)
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Admin_can_hard_delete_comments" ON community_comments;
CREATE POLICY "Admin_can_hard_delete_comments" ON community_comments
  FOR DELETE USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
  );

-- ----------------------------------------------------------------------------
-- LIKES
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Likes_are_public" ON community_post_likes;
CREATE POLICY "Likes_are_public" ON community_post_likes
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users_can_like" ON community_post_likes;
CREATE POLICY "Users_can_like" ON community_post_likes
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND is_banned = false
    )
  );

DROP POLICY IF EXISTS "Users_can_unlike" ON community_post_likes;
CREATE POLICY "Users_can_unlike" ON community_post_likes
  FOR DELETE USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- SAVES
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Saves_are_public" ON community_post_saves;
CREATE POLICY "Saves_are_public" ON community_post_saves
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users_can_save" ON community_post_saves;
CREATE POLICY "Users_can_save" ON community_post_saves
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND is_banned = false
    )
  );

DROP POLICY IF EXISTS "Users_can_unsave" ON community_post_saves;
CREATE POLICY "Users_can_unsave" ON community_post_saves
  FOR DELETE USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- REPORTS
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users_can_create_reports" ON community_reports;
CREATE POLICY "Users_can_create_reports" ON community_reports
  FOR INSERT WITH CHECK (
    auth.uid() = reporter_id
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND is_banned = false
    )
  );

DROP POLICY IF EXISTS "Admins_can_view_reports" ON community_reports;
CREATE POLICY "Admins_can_view_reports" ON community_reports
  FOR SELECT USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
  );

DROP POLICY IF EXISTS "Admins_can_update_reports" ON community_reports;
CREATE POLICY "Admins_can_update_reports" ON community_reports
  FOR UPDATE USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
  );

-- ----------------------------------------------------------------------------
-- BLOCKS
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users_can_view_own_blocks" ON community_blocks;
CREATE POLICY "Users_can_view_own_blocks" ON community_blocks
  FOR SELECT USING (
    auth.uid() = blocker_id
    OR auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'moderator'))
  );

DROP POLICY IF EXISTS "Users_can_block" ON community_blocks;
CREATE POLICY "Users_can_block" ON community_blocks
  FOR INSERT WITH CHECK (
    auth.uid() = blocker_id
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND is_banned = false
    )
  );

DROP POLICY IF EXISTS "Users_can_unblock" ON community_blocks;
CREATE POLICY "Users_can_unblock" ON community_blocks
  FOR DELETE USING (auth.uid() = blocker_id);

-- ============================================================================
-- DOĞRULAMA
-- ============================================================================

-- Çalıştırdıktan sonra şu sorgularla doğrulama yapabilirsin:

-- Tablolar oluştu mu?
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;

-- Policy'ler aktif mi?
-- SELECT tablename, policyname, cmd, permissive, qual FROM pg_policies
-- WHERE tablename IN ('profiles', 'community_posts', 'community_comments', 'community_post_likes', 'community_post_saves', 'community_reports', 'community_blocks')
-- ORDER BY tablename, cmd;

-- Test: Free kullanıcı INSERT yapabilir mi? (cevap: HAYIR — RLS hatası almalı)
-- 1. Auth → kendine test kullanıcısı oluştur
-- 2. profiles tablosuna o kullanıcı için is_pro=false, is_banned=false kaydı ekle
-- 3. O kullanıcı ile giriş yapıp community_posts INSERT dene

-- ============================================================================
