-- ==============================================================================
-- Migration 041: Service Head Role, SQL Helper Functions, and RLS Permissions
-- ==============================================================================

-- 1. Ensure 'service_head' and 'complaints' exist in user_role enum
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'service_head';
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'complaints';

-- 2. SQL Helper: Check if user has Service Head role (primary role or in roles array)
CREATE OR REPLACE FUNCTION public.is_service_head(check_user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = check_user_id
      AND deleted_at IS NULL
      AND (
        role::text = 'service_head'
        OR (roles IS NOT NULL AND 'service_head' = ANY(roles))
      )
  );
$$;

-- 3. SQL Helper: Generic reusable role access checker
CREATE OR REPLACE FUNCTION public.has_role_access(roles_to_check text[], check_user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = check_user_id
      AND deleted_at IS NULL
      AND (
        -- Matches requested role directly in primary role
        role::text = ANY(roles_to_check)
        -- Matches in roles array
        OR (roles IS NOT NULL AND roles && roles_to_check)
        -- Admin always has access to everything
        OR role::text = 'admin'
        OR (roles IS NOT NULL AND 'admin' = ANY(roles))
        -- Service Head has composite access to installation, complaints, boq, crm, and reports
        OR (
          (role::text = 'service_head' OR (roles IS NOT NULL AND 'service_head' = ANY(roles)))
          AND roles_to_check && ARRAY[
            'service_head',
            'installation',
            'complaints',
            'boq',
            'crm_staff',
            'sales',
            'sales_head'
          ]::text[]
        )
      )
  );
$$;

-- 4. Update get_my_role() to properly recognize service_head and complaints
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS public.user_role
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_role public.user_role;
  v_roles text[];
BEGIN
  SELECT role, roles INTO v_role, v_roles FROM public.profiles WHERE id = auth.uid() AND deleted_at IS NULL LIMIT 1;
  
  -- Priority 1: Admin
  IF (v_roles IS NOT NULL AND 'admin' = ANY(v_roles)) OR v_role = 'admin'::public.user_role THEN
    RETURN 'admin'::public.user_role;
  END IF;

  -- Priority 2: Manager
  IF (v_roles IS NOT NULL AND 'manager' = ANY(v_roles)) OR v_role = 'manager'::public.user_role THEN
    RETURN 'manager'::public.user_role;
  END IF;

  -- Priority 3: Sales Head
  IF (v_roles IS NOT NULL AND 'sales_head' = ANY(v_roles)) OR v_role = 'sales_head'::public.user_role THEN
    RETURN 'sales_head'::public.user_role;
  END IF;

  -- Priority 4: Service Head (composite role)
  IF (v_roles IS NOT NULL AND 'service_head' = ANY(v_roles)) OR v_role = 'service_head'::public.user_role THEN
    RETURN 'service_head'::public.user_role;
  END IF;

  IF v_role IS NOT NULL THEN
    RETURN v_role;
  END IF;
  
  -- Check customer_profiles for customer account
  IF EXISTS (SELECT 1 FROM public.customer_profiles WHERE id = auth.uid()) THEN
    RETURN 'customer'::public.user_role;
  END IF;
  
  RETURN NULL;
END;
$function$;

-- 5. RLS Policies for Service Head across all required modules

-- (a) Installations: Service Head gets full company-wide access
DROP POLICY IF EXISTS "service_head_installations_all" ON public.installations;
CREATE POLICY "service_head_installations_all" ON public.installations
  FOR ALL TO authenticated
  USING (public.has_role_access(ARRAY['installation', 'service_head']))
  WITH CHECK (public.has_role_access(ARRAY['installation', 'service_head']));

-- (b) Complaints: Service Head gets full company-wide access
DROP POLICY IF EXISTS "service_head_complaints_all" ON public.complaints;
CREATE POLICY "service_head_complaints_all" ON public.complaints
  FOR ALL TO authenticated
  USING (public.has_role_access(ARRAY['complaints', 'service_head']))
  WITH CHECK (public.has_role_access(ARRAY['complaints', 'service_head']));

-- (c) BOQs & Supplementary Items: Service Head gets company-wide access
DROP POLICY IF EXISTS "service_head_boqs_all" ON public.boqs;
CREATE POLICY "service_head_boqs_all" ON public.boqs
  FOR ALL TO authenticated
  USING (public.has_role_access(ARRAY['boq', 'service_head']))
  WITH CHECK (public.has_role_access(ARRAY['boq', 'service_head']));

DROP POLICY IF EXISTS "service_head_supplementary_items_all" ON public.supplementary_items;
CREATE POLICY "service_head_supplementary_items_all" ON public.supplementary_items
  FOR ALL TO authenticated
  USING (public.has_role_access(ARRAY['boq', 'service_head']))
  WITH CHECK (public.has_role_access(ARRAY['boq', 'service_head']));

-- (d) CRM: crm_leads, crm_prospects, customers, sales_pipelines
DROP POLICY IF EXISTS "service_head_crm_leads_all" ON public.crm_leads;
CREATE POLICY "service_head_crm_leads_all" ON public.crm_leads
  FOR ALL TO authenticated
  USING (public.has_role_access(ARRAY['crm_staff', 'service_head']))
  WITH CHECK (public.has_role_access(ARRAY['crm_staff', 'service_head']));

DROP POLICY IF EXISTS "service_head_crm_prospects_all" ON public.crm_prospects;
CREATE POLICY "service_head_crm_prospects_all" ON public.crm_prospects
  FOR ALL TO authenticated
  USING (public.has_role_access(ARRAY['crm_staff', 'service_head']))
  WITH CHECK (public.has_role_access(ARRAY['crm_staff', 'service_head']));

DROP POLICY IF EXISTS "service_head_customers_all" ON public.customers;
CREATE POLICY "service_head_customers_all" ON public.customers
  FOR ALL TO authenticated
  USING (public.has_role_access(ARRAY['sales', 'sales_head', 'crm_staff', 'service_head']))
  WITH CHECK (public.has_role_access(ARRAY['sales', 'sales_head', 'crm_staff', 'service_head']));

DROP POLICY IF EXISTS "service_head_pipelines_all" ON public.sales_pipelines;
CREATE POLICY "service_head_pipelines_all" ON public.sales_pipelines
  FOR ALL TO authenticated
  USING (public.has_role_access(ARRAY['sales', 'sales_head', 'service_head']))
  WITH CHECK (public.has_role_access(ARRAY['sales', 'sales_head', 'service_head']));

DROP POLICY IF EXISTS "service_head_quotations_all" ON public.quotations;
CREATE POLICY "service_head_quotations_all" ON public.quotations
  FOR ALL TO authenticated
  USING (public.has_role_access(ARRAY['sales', 'sales_head', 'boq', 'service_head']))
  WITH CHECK (public.has_role_access(ARRAY['sales', 'sales_head', 'boq', 'service_head']));

-- (e) Customer Documents & Attachments
DROP POLICY IF EXISTS "service_head_customer_documents_access" ON public.customer_documents;
CREATE POLICY "service_head_customer_documents_access" ON public.customer_documents
  FOR ALL TO authenticated
  USING (public.has_role_access(ARRAY['sales', 'sales_head', 'service_head']))
  WITH CHECK (public.has_role_access(ARRAY['sales', 'sales_head', 'service_head']));

-- (f) Storage bucket access: complaint-photos, customer-documents
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'storage' AND tablename = 'objects') THEN
    BEGIN
      DROP POLICY IF EXISTS "Service Head read customer-documents" ON storage.objects;
      CREATE POLICY "Service Head read customer-documents" ON storage.objects
        FOR SELECT TO authenticated
        USING (bucket_id IN ('customer-documents', 'complaint-photos'));

      DROP POLICY IF EXISTS "Service Head upload customer-documents" ON storage.objects;
      CREATE POLICY "Service Head upload customer-documents" ON storage.objects
        FOR INSERT TO authenticated
        WITH CHECK (bucket_id IN ('customer-documents', 'complaint-photos'));
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;
END $$;

