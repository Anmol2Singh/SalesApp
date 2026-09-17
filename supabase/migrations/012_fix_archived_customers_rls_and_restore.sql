-- Migration 012: Fix RLS policies on customers to allow viewing and restoring archived customers
-- Previously, the USING clause on customers policies included "AND deleted_at IS NULL", which
-- caused PostgreSQL RLS to return 0 rows for archived customers and prevented updates to restore them.

-- 1. Update customers_admin_all
DROP POLICY IF EXISTS customers_admin_all ON customers;
CREATE POLICY customers_admin_all ON customers
  FOR ALL
  TO authenticated
  USING (get_my_role() = 'admin')
  WITH CHECK (get_my_role() = 'admin');

-- 2. Update customers_sales_head_all
DROP POLICY IF EXISTS customers_sales_head_all ON customers;
CREATE POLICY customers_sales_head_all ON customers
  FOR ALL
  TO authenticated
  USING (get_my_role() = 'sales_head')
  WITH CHECK (get_my_role() = 'sales_head');

-- 3. Update customers_sales_own
DROP POLICY IF EXISTS customers_sales_own ON customers;
CREATE POLICY customers_sales_own ON customers
  FOR ALL
  TO authenticated
  USING (
    get_my_role() = 'sales'
    AND (created_by = auth.uid() OR assigned_to = auth.uid())
  )
  WITH CHECK (
    get_my_role() = 'sales'
    AND (created_by = auth.uid() OR assigned_to = auth.uid())
  );

-- 4. Dedicated RPC to reliably restore an archived customer
CREATE OR REPLACE FUNCTION restore_customer(p_customer_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_phone TEXT;
  v_email TEXT;
  v_name TEXT;
  v_user_id UUID;
BEGIN
  -- Clear deleted_at timestamp
  UPDATE customers
  SET deleted_at = NULL,
      updated_at = NOW()
  WHERE id = p_customer_id
  RETURNING phone, email, COALESCE(customer_name, company_name, contact_person)
  INTO v_phone, v_email, v_name;

  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  -- Re-ensure customer_profiles row exists if customer has phone
  IF v_phone IS NOT NULL AND TRIM(v_phone) <> '' THEN
    SELECT id INTO v_user_id FROM auth.users WHERE phone = v_phone LIMIT 1;
    IF v_user_id IS NOT NULL THEN
      INSERT INTO customer_profiles (id, full_name, email, phone, role)
      VALUES (v_user_id, COALESCE(v_name, 'Customer'), NULLIF(TRIM(v_email), ''), v_phone, 'customer')
      ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        email = COALESCE(EXCLUDED.email, customer_profiles.email),
        updated_at = NOW();
    END IF;
  END IF;

  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION restore_customer(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION restore_customer(UUID) TO service_role;
