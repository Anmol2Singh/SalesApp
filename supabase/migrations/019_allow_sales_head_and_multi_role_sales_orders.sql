-- ============================================================
-- Migration 019: Allow Sales Head & Multi-Role to Generate & See Sales Orders
-- ============================================================

-- 1. Helper function: is_sales_head()
CREATE OR REPLACE FUNCTION public.is_sales_head()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() 
      AND (
        role = 'sales_head'::user_role 
        OR (roles IS NOT NULL AND 'sales_head' = ANY(roles))
      )
      AND deleted_at IS NULL
  );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- 2. Helper function: is_admin()
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() 
      AND (
        role = 'admin'::user_role 
        OR (roles IS NOT NULL AND 'admin' = ANY(roles))
      )
      AND deleted_at IS NULL
  );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- 3. Update get_my_role() to recognize admin, sales_head, service_head in roles array
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS user_role
LANGUAGE plpgsql
STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_role user_role;
  v_roles text[];
BEGIN
  SELECT role, roles INTO v_role, v_roles FROM profiles WHERE id = auth.uid() AND deleted_at IS NULL LIMIT 1;
  
  -- If user has admin in roles, priority is admin
  IF (v_roles IS NOT NULL AND 'admin' = ANY(v_roles)) OR v_role = 'admin'::user_role THEN
    RETURN 'admin'::user_role;
  END IF;

  -- If user has sales_head in roles, return sales_head
  IF (v_roles IS NOT NULL AND 'sales_head' = ANY(v_roles)) OR v_role = 'sales_head'::user_role THEN
    RETURN 'sales_head'::user_role;
  END IF;

  -- If user has service_head in roles
  IF (v_roles IS NOT NULL AND 'service_head' = ANY(v_roles)) OR v_role = 'service_head'::user_role THEN
    RETURN 'service_head'::user_role;
  END IF;

  IF v_role IS NOT NULL THEN
    RETURN v_role;
  END IF;
  
  -- Check customer_profiles for customer account
  IF EXISTS (SELECT 1 FROM customer_profiles WHERE id = auth.uid()) THEN
    RETURN 'customer'::user_role;
  END IF;
  
  RETURN NULL;
END;
$function$;

-- 4. Set Sagar Farate's primary role to sales_head
UPDATE profiles 
SET role = 'sales_head'::user_role 
WHERE email = 'sagar18@insiya.com';

-- 5. RLS Policies on sales_orders

-- Sales Head: Full ALL access to generate, view, edit and delete all sales orders
DROP POLICY IF EXISTS sales_orders_sales_head_all ON sales_orders;
CREATE POLICY sales_orders_sales_head_all ON sales_orders
  FOR ALL TO authenticated
  USING (
    ((get_my_role())::text = 'sales_head' OR is_sales_head() OR (get_my_role())::text = 'admin' OR is_admin())
    AND deleted_at IS NULL
  )
  WITH CHECK (
    (get_my_role())::text = 'sales_head' OR is_sales_head() OR (get_my_role())::text = 'admin' OR is_admin()
  );

-- Admin: Full ALL access
DROP POLICY IF EXISTS sales_orders_admin_all ON sales_orders;
CREATE POLICY sales_orders_admin_all ON sales_orders
  FOR ALL TO authenticated
  USING (
    ((get_my_role())::text = 'admin' OR is_admin())
    AND deleted_at IS NULL
  )
  WITH CHECK (
    (get_my_role())::text = 'admin' OR is_admin()
  );

-- Sales Representatives: Full ALL access to sales orders for pipelines created by or assigned to them
DROP POLICY IF EXISTS sales_orders_sales_own ON sales_orders;
CREATE POLICY sales_orders_sales_own ON sales_orders
  FOR ALL TO authenticated
  USING (
    (
      (get_my_role())::text IN ('sales', 'manager')
      OR EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = auth.uid() 
          AND (
            role IN ('sales', 'manager') 
            OR (roles IS NOT NULL AND roles && ARRAY['sales', 'manager']::text[])
          )
      )
    )
    AND (
      pipeline_id IN (
        SELECT sp.id FROM sales_pipelines sp
        LEFT JOIN customers c ON c.id = sp.customer_id
        WHERE (sp.created_by = auth.uid() OR c.assigned_to = auth.uid() OR c.created_by = auth.uid())
          AND sp.deleted_at IS NULL
      )
      OR pipeline_id IS NULL
    )
    AND deleted_at IS NULL
  )
  WITH CHECK (
    (
      (get_my_role())::text IN ('sales', 'manager')
      OR EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = auth.uid() 
          AND (
            role IN ('sales', 'manager') 
            OR (roles IS NOT NULL AND roles && ARRAY['sales', 'manager']::text[])
          )
      )
    )
    AND (
      pipeline_id IN (
        SELECT sp.id FROM sales_pipelines sp
        LEFT JOIN customers c ON c.id = sp.customer_id
        WHERE (sp.created_by = auth.uid() OR c.assigned_to = auth.uid() OR c.created_by = auth.uid())
          AND sp.deleted_at IS NULL
      )
      OR pipeline_id IS NULL
    )
  );

-- Staff read access: all staff can view active sales orders
DROP POLICY IF EXISTS sales_orders_staff_read ON sales_orders;
CREATE POLICY sales_orders_staff_read ON sales_orders
  FOR SELECT TO authenticated
  USING (
    deleted_at IS NULL
  );
