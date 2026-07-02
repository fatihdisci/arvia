-- ============================================================================
-- Arvia — Hesap Tamamen Silme RPC + Mevcut Hesabı Temizleme
-- ============================================================================
-- Bu dosyayı Supabase Dashboard → SQL Editor'da ÇALIŞTIR.
-- Önce RPC fonksiyonunu oluşturur, sonra mevcut anonimleşmiş hesabı siler.
-- ============================================================================

-- ============================================================================
-- BÖLÜM 1: RPC Fonksiyonu — Hesabı tamamen sil
-- ============================================================================
-- Kullanıcı "Hesabı ve Verileri Sil" dediğinde uygulama bu RPC'yi çağırır:
--   - Tüm postlar, yorumlar, beğeniler, kayıtlar, şikayetler, engellemeler
--   - Moderasyon aksiyon logları
--   - Profil
--   - auth.users kaydı (Apple ID bağlantısı kopar)
-- Apple ile tekrar girişte sıfırdan yeni bir kullanıcı oluşur.

CREATE OR REPLACE FUNCTION delete_community_account_full()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Oturum bulunamadı.';
  END IF;

  DELETE FROM community_moderation_actions WHERE actor_id = v_uid;
  DELETE FROM community_blocks WHERE blocker_id = v_uid OR blocked_id = v_uid;
  DELETE FROM community_reports WHERE reporter_id = v_uid;
  UPDATE community_reports SET reviewer_id = NULL WHERE reviewer_id = v_uid;
  DELETE FROM community_post_likes WHERE user_id = v_uid;
  DELETE FROM community_post_saves WHERE user_id = v_uid;
  UPDATE community_moderation_actions
    SET comment_id = NULL
    WHERE comment_id IN (SELECT id FROM community_comments WHERE author_id = v_uid);
  DELETE FROM community_comments WHERE author_id = v_uid;
  UPDATE community_moderation_actions
    SET post_id = NULL
    WHERE post_id IN (SELECT id FROM community_posts WHERE author_id = v_uid);
  DELETE FROM community_posts WHERE author_id = v_uid;
  DELETE FROM profiles WHERE id = v_uid;
  DELETE FROM auth.users WHERE id = v_uid;
END;
$$;

-- ============================================================================
-- BÖLÜM 2: Mevcut anonimleşmiş hesabı temizle
-- ============================================================================
-- NOT: auth.uid() kullanamayız çünkü bu SQL Editor'da doğrudan çalışıyor.
-- Bu yüzden doğrudan UUID ile siliyoruz.

DO $$
DECLARE
  v_uid UUID := '4c7cf39a-c699-49e4-866a-241c0e288638';
BEGIN
  DELETE FROM community_moderation_actions WHERE actor_id = v_uid;
  DELETE FROM community_blocks WHERE blocker_id = v_uid OR blocked_id = v_uid;
  DELETE FROM community_reports WHERE reporter_id = v_uid;
  UPDATE community_reports SET reviewer_id = NULL WHERE reviewer_id = v_uid;
  DELETE FROM community_post_likes WHERE user_id = v_uid;
  DELETE FROM community_post_saves WHERE user_id = v_uid;
  UPDATE community_moderation_actions
    SET comment_id = NULL
    WHERE comment_id IN (SELECT id FROM community_comments WHERE author_id = v_uid);
  DELETE FROM community_comments WHERE author_id = v_uid;
  UPDATE community_moderation_actions
    SET post_id = NULL
    WHERE post_id IN (SELECT id FROM community_posts WHERE author_id = v_uid);
  DELETE FROM community_posts WHERE author_id = v_uid;
  DELETE FROM profiles WHERE id = v_uid;
  DELETE FROM auth.users WHERE id = v_uid;
  RAISE NOTICE 'Hesap tamamen silindi: %', v_uid;
END;
$$;
