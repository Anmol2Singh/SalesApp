-- Migration 034: Fix "Database error querying schema" caused by NULL token columns in auth.users
-- When users are inserted/updated via custom SQL or RPC functions without setting empty strings
-- for token fields, Supabase GoTrue throws "converting NULL to string is unsupported" (500 Database error querying schema).

-- 1. Ensure profiles table has password columns for administrative visibility
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS password TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS plain_password TEXT;

-- 2. Repair all existing user records in auth.users
UPDATE auth.users
SET 
  confirmation_token = COALESCE(confirmation_token, ''),
  recovery_token = COALESCE(recovery_token, ''),
  email_change_token_new = COALESCE(email_change_token_new, ''),
  email_change_token_current = COALESCE(email_change_token_current, ''),
  email_change = COALESCE(email_change, ''),
  reauthentication_token = COALESCE(reauthentication_token, ''),
  phone_change = COALESCE(phone_change, ''),
  phone_change_token = COALESCE(phone_change_token, '')
WHERE 
  confirmation_token IS NULL
  OR recovery_token IS NULL
  OR email_change_token_new IS NULL
  OR email_change_token_current IS NULL
  OR email_change IS NULL
  OR reauthentication_token IS NULL
  OR phone_change IS NULL
  OR phone_change_token IS NULL;

-- 2. Update create_new_user RPC to always provide empty strings for all token fields
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
DECLARE
  v_email TEXT;
  v_password TEXT;
  v_full_name TEXT;
  v_new_role TEXT;
  v_role public.user_role;
  v_existing_id UUID;
  v_new_id UUID;
  v_encrypted_pw TEXT;
BEGIN
  -- 1. Resolve parameters
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
        email_confirmed_at = NOW(),
        confirmation_token = COALESCE(u.confirmation_token, ''),
        recovery_token = COALESCE(u.recovery_token, ''),
        email_change = COALESCE(u.email_change, ''),
        email_change_token_new = COALESCE(u.email_change_token_new, ''),
        email_change_token_current = COALESCE(u.email_change_token_current, ''),
        reauthentication_token = COALESCE(u.reauthentication_token, ''),
        phone_change = COALESCE(u.phone_change, ''),
        phone_change_token = COALESCE(u.phone_change_token, '')
      WHERE u.id = v_existing_id;

      INSERT INTO public.profiles (
        id, email, full_name, role, roles, is_active, password, plain_password, created_at, updated_at
      ) VALUES (
        v_existing_id,
        v_email,
        v_full_name,
        v_role,
        ARRAY[v_new_role],
        true,
        v_password,
        v_password,
        NOW(),
        NOW()
      )
      ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        roles = EXCLUDED.roles,
        password = EXCLUDED.password,
        plain_password = EXCLUDED.plain_password,
        is_active = true,
        updated_at = NOW();

      RETURN jsonb_build_object('success', true, 'user_id', v_existing_id, 'recreated', true);
    END IF;
  END IF;

  -- 5. Fresh user creation with all GoTrue string token columns initialized to empty strings
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
    recovery_token,
    email_change,
    email_change_token_new,
    email_change_token_current,
    reauthentication_token,
    phone_change,
    phone_change_token
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
    '',
    '',
    '',
    '',
    '',
    '',
    ''
  );

  INSERT INTO public.profiles (
    id, email, full_name, role, roles, is_active, password, plain_password, created_at, updated_at
  ) VALUES (
    v_new_id,
    v_email,
    v_full_name,
    v_role,
    ARRAY[v_new_role],
    true,
    v_password,
    v_password,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    roles = EXCLUDED.roles,
    password = EXCLUDED.password,
    plain_password = EXCLUDED.plain_password,
    is_active = true,
    updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'user_id', v_new_id);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 3. Update edit_existing_user to update password in auth.users and profiles
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
  v_role public.user_role;
BEGIN
  IF target_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Target user ID is required');
  END IF;

  IF new_email IS NOT NULL AND TRIM(new_email) != '' THEN
    UPDATE auth.users
    SET 
      email = LOWER(TRIM(new_email)),
      updated_at = NOW()
    WHERE id = target_user_id;

    UPDATE public.profiles
    SET 
      email = LOWER(TRIM(new_email)),
      updated_at = NOW()
    WHERE id = target_user_id;
  END IF;

  IF new_password IS NOT NULL AND TRIM(new_password) != '' THEN
    UPDATE auth.users
    SET 
      encrypted_password = extensions.crypt(new_password, extensions.gen_salt('bf')),
      confirmation_token = COALESCE(confirmation_token, ''),
      recovery_token = COALESCE(recovery_token, ''),
      email_change = COALESCE(email_change, ''),
      email_change_token_new = COALESCE(email_change_token_new, ''),
      email_change_token_current = COALESCE(email_change_token_current, ''),
      reauthentication_token = COALESCE(reauthentication_token, ''),
      updated_at = NOW()
    WHERE id = target_user_id;

    UPDATE public.profiles
    SET 
      password = new_password,
      plain_password = new_password,
      updated_at = NOW()
    WHERE id = target_user_id;
  END IF;

  IF new_full_name IS NOT NULL AND TRIM(new_full_name) != '' THEN
    UPDATE auth.users
    SET 
      raw_user_meta_data = jsonb_set(
        COALESCE(raw_user_meta_data, '{}'::jsonb),
        '{full_name}',
        to_jsonb(TRIM(new_full_name))
      ),
      updated_at = NOW()
    WHERE id = target_user_id;

    UPDATE public.profiles
    SET 
      full_name = TRIM(new_full_name),
      updated_at = NOW()
    WHERE id = target_user_id;
  END IF;

  IF new_role IS NOT NULL AND TRIM(new_role) != '' THEN
    BEGIN
      v_role := LOWER(TRIM(new_role))::user_role;
    EXCEPTION WHEN OTHERS THEN
      v_role := 'sales'::user_role;
    END;

    UPDATE auth.users
    SET 
      raw_user_meta_data = jsonb_set(
        COALESCE(raw_user_meta_data, '{}'::jsonb),
        '{role}',
        to_jsonb(LOWER(TRIM(new_role)))
      ),
      updated_at = NOW()
    WHERE id = target_user_id;

    UPDATE public.profiles
    SET 
      role = v_role,
      roles = ARRAY[LOWER(TRIM(new_role))],
      updated_at = NOW()
    WHERE id = target_user_id;
  END IF;

  RETURN jsonb_build_object('success', true);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_new_user TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.edit_existing_user TO authenticated, service_role, anon;
