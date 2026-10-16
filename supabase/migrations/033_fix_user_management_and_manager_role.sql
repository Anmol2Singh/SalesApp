-- ============================================================
-- Migration 033: Fix User Management RPCs & Support Manager Role
-- Resolves "function gen_salt(unknown, integer) does not exist"
-- Adds 'manager', 'technician', 'crm_staff', and 'accounts' to user_role enum
-- ============================================================

-- 1. Ensure pgcrypto extension is installed in extensions schema
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA extensions TO postgres, anon, authenticated, service_role;

-- 2. Add missing roles to user_role enum
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'manager';
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'technician';
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'crm_staff';
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'accounts';

-- 3. Clean and robust create_new_user RPC with explicit extensions.crypt & extensions.gen_salt
CREATE OR REPLACE FUNCTION public.create_new_user(
  email TEXT DEFAULT NULL,
  password TEXT DEFAULT NULL,
  full_name TEXT DEFAULT NULL,
  new_role TEXT DEFAULT NULL,
  p_email TEXT DEFAULT NULL,
  p_password TEXT DEFAULT NULL,
  p_full_name TEXT DEFAULT NULL,
  p_new_role TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
#variable_conflict use_variable
DECLARE
  v_email TEXT;
  v_password TEXT;
  v_full_name TEXT;
  v_new_role TEXT;
  v_existing_id UUID;
  v_new_id UUID;
  v_encrypted_pw TEXT;
  v_role user_role;
BEGIN
  -- 1. Resolve parameters safely (supports both 'email' and 'p_email' styles)
  v_email := LOWER(TRIM(COALESCE(create_new_user.email, create_new_user.p_email, '')));
  v_password := COALESCE(create_new_user.password, create_new_user.p_password, '');
  v_full_name := TRIM(COALESCE(create_new_user.full_name, create_new_user.p_full_name, ''));
  v_new_role := LOWER(TRIM(COALESCE(create_new_user.new_role, create_new_user.p_new_role, 'sales')));

  -- 2. Validate input
  IF v_email = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Email is required');
  END IF;
  IF v_password = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Password is required');
  END IF;
  IF v_full_name = '' THEN
    v_full_name := split_part(v_email, '@', 1);
  END IF;

  -- 3. Validate role
  BEGIN
    v_role := v_new_role::user_role;
  EXCEPTION WHEN OTHERS THEN
    v_role := 'sales'::user_role;
  END;

  -- 4. Check if user exists in auth.users
  SELECT u.id INTO v_existing_id 
  FROM auth.users u 
  WHERE LOWER(TRIM(u.email)) = v_email;

  IF v_existing_id IS NOT NULL THEN
    -- If active profile exists, return error
    IF EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_existing_id AND p.is_active = true) THEN
      RETURN jsonb_build_object('success', false, 'error', 'User with this email already exists');
    ELSE
      -- Previously deleted/orphaned user: reactivate with new credentials & metadata
      v_encrypted_pw := extensions.crypt(v_password, extensions.gen_salt('bf'));

      UPDATE auth.users u SET
        encrypted_password = v_encrypted_pw,
        email = v_email,
        raw_user_meta_data = jsonb_build_object('full_name', v_full_name, 'role', v_new_role),
        updated_at = NOW(),
        email_confirmed_at = NOW()
      WHERE u.id = v_existing_id;

      INSERT INTO public.profiles (
        id, email, full_name, role, roles, is_active, created_at, updated_at
      ) VALUES (
        v_existing_id,
        v_email,
        v_full_name,
        v_role,
        ARRAY[v_new_role],
        true,
        NOW(),
        NOW()
      )
      ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        roles = EXCLUDED.roles,
        is_active = true,
        updated_at = NOW();

      RETURN jsonb_build_object('success', true, 'user_id', v_existing_id, 'recreated', true);
    END IF;
  END IF;

  -- 5. Fresh user creation
  v_new_id := gen_random_uuid();
  v_encrypted_pw := extensions.crypt(v_password, extensions.gen_salt('bf'));

  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_new_id,
    'authenticated',
    'authenticated',
    v_email,
    v_encrypted_pw,
    NOW(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('full_name', v_full_name, 'role', v_new_role),
    NOW(),
    NOW(),
    '',
    ''
  );

  INSERT INTO public.profiles (
    id, email, full_name, role, roles, is_active, created_at, updated_at
  ) VALUES (
    v_new_id,
    v_email,
    v_full_name,
    v_role,
    ARRAY[v_new_role],
    true,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    roles = EXCLUDED.roles,
    is_active = true,
    updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'user_id', v_new_id);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 4. Recreate edit_existing_user with explicit extensions qualification
CREATE OR REPLACE FUNCTION public.edit_existing_user(
  target_user_id UUID,
  new_email TEXT DEFAULT NULL,
  new_password TEXT DEFAULT NULL,
  new_full_name TEXT DEFAULT NULL,
  new_role TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_role user_role;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = target_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF new_email IS NOT NULL AND TRIM(new_email) != '' THEN
    UPDATE auth.users SET
      email = LOWER(TRIM(new_email)),
      updated_at = NOW()
    WHERE id = target_user_id;

    UPDATE public.profiles SET
      email = LOWER(TRIM(new_email)),
      updated_at = NOW()
    WHERE id = target_user_id;
  END IF;

  IF new_password IS NOT NULL AND TRIM(new_password) != '' THEN
    UPDATE auth.users SET
      encrypted_password = extensions.crypt(new_password, extensions.gen_salt('bf')),
      updated_at = NOW()
    WHERE id = target_user_id;
  END IF;

  IF new_full_name IS NOT NULL AND TRIM(new_full_name) != '' THEN
    UPDATE public.profiles SET
      full_name = TRIM(new_full_name),
      updated_at = NOW()
    WHERE id = target_user_id;

    UPDATE auth.users SET
      raw_user_meta_data = raw_user_meta_data || jsonb_build_object('full_name', TRIM(new_full_name)),
      updated_at = NOW()
    WHERE id = target_user_id;
  END IF;

  IF new_role IS NOT NULL AND TRIM(new_role) != '' THEN
    BEGIN
      v_role := new_role::user_role;
      UPDATE public.profiles SET
        role = v_role,
        roles = ARRAY[new_role],
        updated_at = NOW()
      WHERE id = target_user_id;
    EXCEPTION WHEN OTHERS THEN
      UPDATE public.profiles SET
        roles = ARRAY[new_role],
        updated_at = NOW()
      WHERE id = target_user_id;
    END;

    UPDATE auth.users SET
      raw_user_meta_data = raw_user_meta_data || jsonb_build_object('role', new_role),
      updated_at = NOW()
    WHERE id = target_user_id;
  END IF;

  RETURN jsonb_build_object('success', true);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 5. Grant permissions
GRANT EXECUTE ON FUNCTION public.create_new_user TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.edit_existing_user TO authenticated, service_role;
