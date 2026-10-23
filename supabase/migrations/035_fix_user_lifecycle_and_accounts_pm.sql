-- ============================================================================
-- Migration: 035_fix_user_lifecycle_and_accounts_pm.sql
-- Description:
-- 1. Fix user deletion & recreation lifecycle:
--    If user has contributed records (deals, customers, complaints, etc.),
--    soft-deactivate rather than failing. If re-created, reactivate profile.
-- 2. Allow 'accounts' role full visibility over customers, vendors, and PM tables.
-- ============================================================================

-- 1. Update delete_existing_user RPC to soft-delete if foreign key constraint restricts hard delete
CREATE OR REPLACE FUNCTION delete_existing_user(target_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_user_email TEXT;
BEGIN
  SELECT email INTO v_user_email FROM public.profiles WHERE id = target_user_id;

  -- Attempt unlinking optional references
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

  -- Remove from technicians table
  BEGIN
    DELETE FROM public.technicians WHERE id = target_user_id;
    IF v_user_email IS NOT NULL AND v_user_email <> '' THEN
      DELETE FROM public.technicians WHERE LOWER(email) = LOWER(v_user_email);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    UPDATE public.technicians SET status = 'Inactive' WHERE id = target_user_id;
  END;

  -- Attempt hard delete of profile and auth.users
  BEGIN
    DELETE FROM public.customer_profiles WHERE id = target_user_id;
    DELETE FROM public.profiles WHERE id = target_user_id;
    DELETE FROM auth.users WHERE id = target_user_id;
    RETURN jsonb_build_object('success', true, 'message', 'User permanently deleted');
  EXCEPTION WHEN OTHERS THEN
    -- Fallback: Soft-deactivate contributed user so historical links remain intact
    UPDATE public.profiles SET
      is_active = false,
      deleted_at = NOW(),
      updated_at = NOW()
    WHERE id = target_user_id;

    RETURN jsonb_build_object('success', true, 'deactivated', true, 'message', 'User contributed data and was deactivated instead of deleted');
  END;
END;
$$;

GRANT EXECUTE ON FUNCTION delete_existing_user(UUID) TO authenticated, service_role;


-- 2. Update create_new_user RPC to cleanly reactivate existing or inactive users
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

  -- 4. Check if user exists in auth.users or profiles
  SELECT u.id INTO v_existing_id 
  FROM auth.users u 
  WHERE LOWER(TRIM(u.email)) = v_email;

  IF v_existing_id IS NULL THEN
    SELECT p.id INTO v_existing_id
    FROM public.profiles p
    WHERE LOWER(TRIM(p.email)) = v_email;
  END IF;

  IF v_existing_id IS NOT NULL THEN
    -- If an actively working profile exists, return error
    IF EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_existing_id AND p.is_active = true AND p.deleted_at IS NULL) THEN
      RETURN jsonb_build_object('success', false, 'error', 'User with this email already exists');
    ELSE
      -- Previously deleted/deactivated user: reactivate with new credentials & metadata
      v_encrypted_pw := extensions.crypt(v_password, extensions.gen_salt('bf'));

      BEGIN
        UPDATE auth.users u SET
          encrypted_password = v_encrypted_pw,
          email = v_email,
          raw_user_meta_data = jsonb_build_object('full_name', v_full_name, 'role', v_new_role),
          updated_at = NOW(),
          email_confirmed_at = NOW()
        WHERE u.id = v_existing_id;
      EXCEPTION WHEN OTHERS THEN NULL;
      END;

      INSERT INTO public.profiles (
        id, email, full_name, role, roles, is_active, deleted_at, password, plain_password, created_at, updated_at
      ) VALUES (
        v_existing_id,
        v_email,
        v_full_name,
        v_role,
        ARRAY[v_new_role],
        true,
        NULL,
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
        deleted_at = NULL,
        updated_at = NOW();

      -- If technician role, re-activate or insert in technicians table
      IF v_new_role = 'technician' THEN
        BEGIN
          INSERT INTO public.technicians (id, name, email, status, rating, active_tasks_count)
          VALUES (v_existing_id, v_full_name, v_email, 'Available', 4.9, 0)
          ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            email = EXCLUDED.email,
            status = 'Available';
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
      END IF;

      RETURN jsonb_build_object('success', true, 'user_id', v_existing_id, 'reactivated', true);
    END IF;
  END IF;

  -- 5. Fresh user creation
  v_new_id := gen_random_uuid();
  v_encrypted_pw := extensions.crypt(v_password, extensions.gen_salt('bf'));

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change, email_change_token_new,
    email_change_token_current, reauthentication_token, phone_change, phone_change_token
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
    '', '', '', '', '', '', '', ''
  );

  INSERT INTO public.profiles (
    id, email, full_name, role, roles, is_active, deleted_at, password, plain_password, created_at, updated_at
  ) VALUES (
    v_new_id,
    v_email,
    v_full_name,
    v_role,
    ARRAY[v_new_role],
    true,
    NULL,
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
    deleted_at = NULL,
    updated_at = NOW();

  IF v_new_role = 'technician' THEN
    BEGIN
      INSERT INTO public.technicians (id, name, email, status, rating, active_tasks_count)
      VALUES (v_new_id, v_full_name, v_email, 'Available', 4.9, 0);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;

  RETURN jsonb_build_object('success', true, 'user_id', v_new_id);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_new_user TO authenticated, service_role, anon;


-- 3. Allow 'accounts' role to view all customers
DROP POLICY IF EXISTS customers_service_staff_read ON customers;
CREATE POLICY customers_service_staff_read ON customers
  FOR SELECT
  TO authenticated
  USING (
    get_my_role() IN ('service_head', 'installation', 'technician', 'manager', 'accounts')
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND (
          role::text IN ('service_head', 'installation', 'technician', 'manager', 'accounts')
          OR (roles IS NOT NULL AND roles && ARRAY['service_head', 'installation', 'technician', 'manager', 'accounts']::text[])
        )
    )
  );

-- 4. Allow 'accounts' role access to all Project Manager (pm_*) tables
DROP POLICY IF EXISTS pm_projects_admin_all ON pm_projects;
CREATE POLICY pm_projects_admin_all ON pm_projects
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager', 'accounts'))
  WITH CHECK (get_my_role() IN ('admin', 'manager', 'accounts'));

DROP POLICY IF EXISTS pm_purchases_admin_all ON pm_purchases;
CREATE POLICY pm_purchases_admin_all ON pm_purchases
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager', 'accounts'))
  WITH CHECK (get_my_role() IN ('admin', 'manager', 'accounts'));

DROP POLICY IF EXISTS pm_payment_terms_admin_all ON pm_payment_terms;
CREATE POLICY pm_payment_terms_admin_all ON pm_payment_terms
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager', 'accounts'))
  WITH CHECK (get_my_role() IN ('admin', 'manager', 'accounts'));

DROP POLICY IF EXISTS pm_ledger_entries_admin_all ON pm_ledger_entries;
CREATE POLICY pm_ledger_entries_admin_all ON pm_ledger_entries
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager', 'accounts'))
  WITH CHECK (get_my_role() IN ('admin', 'manager', 'accounts'));

DROP POLICY IF EXISTS pm_purchase_ledger_admin_all ON pm_purchase_ledger_entries;
CREATE POLICY pm_purchase_ledger_admin_all ON pm_purchase_ledger_entries
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager', 'accounts'))
  WITH CHECK (get_my_role() IN ('admin', 'manager', 'accounts'));

DROP POLICY IF EXISTS pm_expenses_admin_all ON pm_expenses;
CREATE POLICY pm_expenses_admin_all ON pm_expenses
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager', 'accounts'))
  WITH CHECK (get_my_role() IN ('admin', 'manager', 'accounts'));

DROP POLICY IF EXISTS pm_calling_records_admin_all ON pm_calling_records;
CREATE POLICY pm_calling_records_admin_all ON pm_calling_records
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager', 'accounts'))
  WITH CHECK (get_my_role() IN ('admin', 'manager', 'accounts'));

DROP POLICY IF EXISTS pm_swh_checklist_admin_all ON pm_swh_checklist;
CREATE POLICY pm_swh_checklist_admin_all ON pm_swh_checklist
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager', 'accounts'))
  WITH CHECK (get_my_role() IN ('admin', 'manager', 'accounts'));

DROP POLICY IF EXISTS pm_work_remarks_admin_all ON pm_work_remarks;
CREATE POLICY pm_work_remarks_admin_all ON pm_work_remarks
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager', 'accounts'))
  WITH CHECK (get_my_role() IN ('admin', 'manager', 'accounts'));

DROP POLICY IF EXISTS pm_daily_transactions_admin_all ON pm_daily_transactions;
CREATE POLICY pm_daily_transactions_admin_all ON pm_daily_transactions
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager', 'accounts'))
  WITH CHECK (get_my_role() IN ('admin', 'manager', 'accounts'));

DROP POLICY IF EXISTS pm_app_settings_admin_all ON pm_app_settings;
CREATE POLICY pm_app_settings_admin_all ON pm_app_settings
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager', 'accounts'))
  WITH CHECK (get_my_role() IN ('admin', 'manager', 'accounts'));
