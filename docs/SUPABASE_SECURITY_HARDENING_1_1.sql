-- Arvia 1.1 — profile privilege-escalation hardening
-- Run in Supabase SQL Editor before the 1.1 client is released.
-- Idempotent. The service_role/database owner keeps full administrative access.

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users_can_insert_own_profile" ON public.profiles;
CREATE POLICY "Users_can_insert_own_profile" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users_can_update_own_profile" ON public.profiles;
CREATE POLICY "Users_can_update_own_profile" ON public.profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id AND is_banned = false)
  WITH CHECK (auth.uid() = id);

-- RLS controls rows, not columns. Without these grants a user can insert/update
-- role, is_pro, is_verified or is_banned on their own row and then call the
-- SECURITY DEFINER moderation RPCs as an administrator.
REVOKE INSERT, UPDATE ON TABLE public.profiles FROM anon, authenticated;

GRANT INSERT (
  id,
  username,
  display_name,
  avatar_url,
  default_vehicle_brand,
  default_vehicle_model,
  default_vehicle_year,
  show_vehicle_on_posts
) ON TABLE public.profiles TO authenticated;

GRANT UPDATE (
  username,
  display_name,
  avatar_url,
  default_vehicle_brand,
  default_vehicle_model,
  default_vehicle_year,
  show_vehicle_on_posts
) ON TABLE public.profiles TO authenticated;

-- Keep public profile reads used by the community feed.
GRANT SELECT ON TABLE public.profiles TO anon, authenticated;

-- Explicitly keep sensitive defaults safe for every future insert.
ALTER TABLE public.profiles ALTER COLUMN role SET DEFAULT 'user';
ALTER TABLE public.profiles ALTER COLUMN is_verified SET DEFAULT false;
ALTER TABLE public.profiles ALTER COLUMN is_banned SET DEFAULT false;
ALTER TABLE public.profiles ALTER COLUMN is_pro SET DEFAULT false;

-- Operational verification (run as an authenticated non-admin through the API):
-- 1) INSERT own profile with role='admin' must return permission denied.
-- 2) UPDATE own profile SET is_pro=true must return permission denied.
-- 3) UPDATE own display_name must succeed.
-- 4) Moderation RPC called by the same user must remain unauthorized.
