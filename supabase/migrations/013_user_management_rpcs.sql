-- ============================================================
-- Migration 013: User Management RPCs (Create, Delete, Edit & Recreate)
-- Allows Admin to manage profiles and auth.users cleanly without orphan conflicts
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Function to cleanly delete a user from public tables and auth.users
CREATE OR REPLACE FUNCTION delete_existing_user(target_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
BEGIN
  -- Unlink foreign key references before deleting
  BEGIN
    UPDATE public.complaints SET technician_id = NULL WHERE technician_id = target_user_id;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    UPDATE public.service_requests SET technician_id = NULL WHERE technician_id = target_user_id;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    UPDATE public.crm_prospects SET assigned_to = NULL WHERE assigned_to = target_user_id;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    UPDATE public.crm_leads SET assigned_to = NULL WHERE assigned_to = target_user_id;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    UPDATE public.prospects SET assigned_to = NULL WHERE assigned_to = target_user_id;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    UPDATE public.leads SET assigned_to = NULL WHERE assigned_to = target_user_id;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    UPDATE public.sales_pipelines SET assigned_to = NULL WHERE assigned_to = target_user_id;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    DELETE FROM public.notifications WHERE user_id = target_user_id;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  -- Delete from public tables
  DELETE FROM public.profiles WHERE id = target_user_id;
  DELETE FROM public.customer_profiles WHERE id = target_user_id;
  DELETE FROM public.technicians WHERE id = target_user_id;

  -- Delete from auth.users (completely terminates auth session)
  DELETE FROM auth.users WHERE id = target_user_id;

  RETURN jsonb_build_object('success', true, 'message', 'User deleted successfully');
EXCEPTION WHEN OTHERS THEN
  -- Fallback: Ensure profile is removed even if a foreign key restricts auth.users delete
  DELETE FROM public.profiles WHERE id = target_user_id;
  RETURN jsonb_build_object('success', true, 'warning', SQLERRM);
END;
$$;

-- 2. Function to create a user, gracefully recreating any previously deleted/orphaned accounts
CREATE OR REPLACE FUNCTION create_new_user(
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
  IF LENGTH(v_password) < 6 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Password must be at least 6 characters');
  END IF;

  -- 3. Map role aliases if passed from UI display names
  IF v_new_role = 'complaints' OR v_new_role = 'complaints staff' OR v_new_role = 'complaints_staff' THEN
    v_new_role := 'service_head';
  ELSIF v_new_role = 'material' OR v_new_role = 'material requisition staff' OR v_new_role = 'material_requisition' OR v_new_role = 'purchase' THEN
    v_new_role := 'purchase';
  ELSIF v_new_role = 'factory staff' OR v_new_role = 'factory_staff' THEN
    v_new_role := 'factory';
  ELSIF v_new_role = 'boq staff' OR v_new_role = 'boq_staff' THEN
    v_new_role := 'boq';
  ELSIF v_new_role = 'crm staff' OR v_new_role = 'crm_staff' THEN
    v_new_role := 'crm_staff';
  ELSIF v_new_role = 'sales executive' OR v_new_role = 'sales' THEN
    v_new_role := 'sales';
  ELSIF v_new_role = 'sales head' OR v_new_role = 'sales_head' THEN
    v_new_role := 'sales_head';
  END IF;

  BEGIN
    v_role := v_new_role::user_role;
  EXCEPTION WHEN OTHERS THEN
    v_role := 'sales'::user_role;
    v_new_role := 'sales';
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
      v_encrypted_pw := crypt(v_password, gen_salt('bf'));

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

  -- 5. Fresh user
  v_new_id := gen_random_uuid();
  v_encrypted_pw := crypt(v_password, gen_salt('bf'));

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
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 3. Function to edit an existing user
CREATE OR REPLACE FUNCTION edit_existing_user(
  target_user_id UUID,
  new_email TEXT,
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
      encrypted_password = crypt(new_password, gen_salt('bf')),
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
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'User updated successfully');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION delete_existing_user(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION create_new_user(TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION edit_existing_user(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;
