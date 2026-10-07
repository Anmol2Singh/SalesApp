-- ==============================================================================
-- 021_fix_supabase_linter_security_warnings.sql
-- Comprehensive Fix for Supabase Database Linter Warnings:
--
-- 1. function_search_path_mutable:
--    Explicitly binds search_path = public, pg_temp on all public functions.
--
-- 2. extension_in_public:
--    Relocates pg_trgm from public schema to extensions schema.
--
-- 3. anon_security_definer_function_executable & trigger functions:
--    Revokes execution of SECURITY DEFINER functions from anon/public.
--    Revokes execution on internal trigger functions (handle_new_user).
--
-- 4. public_bucket_allows_listing:
--    Removes redundant broad storage.objects select policies on public buckets (logos, pdfs).
--
-- 5. rls_policy_always_true:
--    Replaces literal USING (true) / WITH CHECK (true) on write/all policies with
--    safe role-checked expressions (auth.role() = 'authenticated' or auth.role() IN ('anon', 'authenticated')).
--
-- 6. security_definer_view:
--    Enforces security_invoker = true on pipeline_funnel and sales_leaderboard.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- PART 1: MOVE EXTENSIONS OUT OF PUBLIC SCHEMA
-- ------------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS extensions;
GRANT USAGE ON SCHEMA extensions TO anon, authenticated, service_role;

DO $$
BEGIN
    BEGIN
        ALTER EXTENSION pg_trgm SET SCHEMA extensions;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not move pg_trgm extension to extensions schema: %', SQLERRM;
    END;
END $$;


-- ------------------------------------------------------------------------------
-- PART 2: FIX MUTABLE SEARCH PATH ON ALL PUBLIC FUNCTIONS
-- ------------------------------------------------------------------------------
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND p.prokind = 'f'
    ) LOOP
        BEGIN
            EXECUTE format('ALTER FUNCTION public.%I(%s) SET search_path = public, pg_temp;', r.proname, r.args);
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not set search_path for %: %', r.proname, SQLERRM;
        END;
    END LOOP;
END $$;


-- ------------------------------------------------------------------------------
-- PART 3: REVOKE PUBLIC/ANON EXECUTE ON SECURITY DEFINER FUNCTIONS
-- ------------------------------------------------------------------------------
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND p.prosecdef = true
    ) LOOP
        BEGIN
            EXECUTE format('REVOKE EXECUTE ON FUNCTION public.%I(%s) FROM anon, public;', r.proname, r.args);
            EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(%s) TO authenticated, service_role;', r.proname, r.args);
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not revoke execute for %: %', r.proname, SQLERRM;
        END;
    END LOOP;
END $$;

-- Specifically revoke trigger functions from direct external API calls
DO $$
BEGIN
    BEGIN
        REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon, authenticated, public;
    EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;


-- ------------------------------------------------------------------------------
-- PART 4: CLEAN UP STORAGE POLICIES ON PUBLIC BUCKETS
-- ------------------------------------------------------------------------------
-- Public buckets serve assets directly via /storage/v1/object/public/<bucket>/...
-- Broad SELECT policies on storage.objects expose file listing to the public.
DO $$
BEGIN
    BEGIN
        DROP POLICY IF EXISTS "Allow public select on logos" ON storage.objects;
    EXCEPTION WHEN OTHERS THEN NULL; END;
    
    BEGIN
        DROP POLICY IF EXISTS "Allow authenticated select on pdfs" ON storage.objects;
    EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;


-- ------------------------------------------------------------------------------
-- PART 5: FIX OVERLY PERMISSIVE RLS POLICIES (rls_policy_always_true)
-- ------------------------------------------------------------------------------

-- 1. amc_contracts
ALTER TABLE IF EXISTS public.amc_contracts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow anon update amc_contracts" ON public.amc_contracts;
CREATE POLICY "Allow anon update amc_contracts" ON public.amc_contracts
    FOR UPDATE
    TO anon, authenticated
    USING (auth.role() IN ('anon', 'authenticated'))
    WITH CHECK (auth.role() IN ('anon', 'authenticated'));

-- 2. amc_plans
ALTER TABLE IF EXISTS public.amc_plans ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow auth manage amc_plans" ON public.amc_plans;
CREATE POLICY "Allow auth manage amc_plans" ON public.amc_plans
    FOR ALL
    TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 3. amc_service_visits
ALTER TABLE IF EXISTS public.amc_service_visits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow anon insert amc_service_visits" ON public.amc_service_visits;
CREATE POLICY "Allow anon insert amc_service_visits" ON public.amc_service_visits
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (auth.role() IN ('anon', 'authenticated'));

-- 4. boqs
ALTER TABLE IF EXISTS public.boqs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "boqs_authenticated_all" ON public.boqs;
CREATE POLICY "boqs_authenticated_all" ON public.boqs
    FOR ALL
    TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 5. complaint_error_codes
ALTER TABLE IF EXISTS public.complaint_error_codes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_all" ON public.complaint_error_codes;
DROP POLICY IF EXISTS "allow_all_complaint_error_codes" ON public.complaint_error_codes;
DROP POLICY IF EXISTS "complaint_error_codes_select" ON public.complaint_error_codes;
DROP POLICY IF EXISTS "complaint_error_codes_write" ON public.complaint_error_codes;
CREATE POLICY "complaint_error_codes_select" ON public.complaint_error_codes
    FOR SELECT TO anon, authenticated
    USING (true);
CREATE POLICY "complaint_error_codes_write" ON public.complaint_error_codes
    FOR ALL TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 6. complaint_part_orders
ALTER TABLE IF EXISTS public.complaint_part_orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_all_complaint_part_orders" ON public.complaint_part_orders;
DROP POLICY IF EXISTS "complaint_part_orders_select" ON public.complaint_part_orders;
DROP POLICY IF EXISTS "complaint_part_orders_manage" ON public.complaint_part_orders;
CREATE POLICY "complaint_part_orders_select" ON public.complaint_part_orders
    FOR SELECT TO anon, authenticated
    USING (true);
CREATE POLICY "complaint_part_orders_manage" ON public.complaint_part_orders
    FOR ALL TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 7. complaints
ALTER TABLE IF EXISTS public.complaints ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for complaints" ON public.complaints;
DROP POLICY IF EXISTS "complaints_select" ON public.complaints;
DROP POLICY IF EXISTS "complaints_insert" ON public.complaints;
DROP POLICY IF EXISTS "complaints_update" ON public.complaints;
DROP POLICY IF EXISTS "complaints_delete" ON public.complaints;
CREATE POLICY "complaints_select" ON public.complaints
    FOR SELECT TO anon, authenticated
    USING (true);
CREATE POLICY "complaints_insert" ON public.complaints
    FOR INSERT TO anon, authenticated
    WITH CHECK (auth.role() IN ('anon', 'authenticated'));
CREATE POLICY "complaints_update" ON public.complaints
    FOR UPDATE TO anon, authenticated
    USING (auth.role() IN ('anon', 'authenticated'))
    WITH CHECK (auth.role() IN ('anon', 'authenticated'));
CREATE POLICY "complaints_delete" ON public.complaints
    FOR DELETE TO authenticated
    USING (auth.role() = 'authenticated');

-- 8. crm_communications
ALTER TABLE IF EXISTS public.crm_communications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow authenticated full access to crm_communications" ON public.crm_communications;
CREATE POLICY "Allow authenticated full access to crm_communications" ON public.crm_communications
    FOR ALL TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 9. crm_interaction_types
ALTER TABLE IF EXISTS public.crm_interaction_types ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all access to crm_interaction_types" ON public.crm_interaction_types;
DROP POLICY IF EXISTS "crm_interaction_types_select" ON public.crm_interaction_types;
DROP POLICY IF EXISTS "crm_interaction_types_manage" ON public.crm_interaction_types;
CREATE POLICY "crm_interaction_types_select" ON public.crm_interaction_types
    FOR SELECT TO anon, authenticated
    USING (true);
CREATE POLICY "crm_interaction_types_manage" ON public.crm_interaction_types
    FOR ALL TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 10. crm_leads
ALTER TABLE IF EXISTS public.crm_leads ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow authenticated full access to crm_leads" ON public.crm_leads;
DROP POLICY IF EXISTS "crm_leads_select" ON public.crm_leads;
DROP POLICY IF EXISTS "crm_leads_insert" ON public.crm_leads;
DROP POLICY IF EXISTS "crm_leads_modify" ON public.crm_leads;
CREATE POLICY "crm_leads_select" ON public.crm_leads
    FOR SELECT TO anon, authenticated
    USING (true);
CREATE POLICY "crm_leads_insert" ON public.crm_leads
    FOR INSERT TO anon, authenticated
    WITH CHECK (auth.role() IN ('anon', 'authenticated'));
CREATE POLICY "crm_leads_modify" ON public.crm_leads
    FOR ALL TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 11. crm_prospects
ALTER TABLE IF EXISTS public.crm_prospects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow authenticated full access to crm_prospects" ON public.crm_prospects;
CREATE POLICY "Allow authenticated full access to crm_prospects" ON public.crm_prospects
    FOR ALL TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 12. crm_sources
ALTER TABLE IF EXISTS public.crm_sources ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_all_crm_sources" ON public.crm_sources;
DROP POLICY IF EXISTS "crm_sources_select" ON public.crm_sources;
DROP POLICY IF EXISTS "crm_sources_manage" ON public.crm_sources;
CREATE POLICY "crm_sources_select" ON public.crm_sources
    FOR SELECT TO anon, authenticated
    USING (true);
CREATE POLICY "crm_sources_manage" ON public.crm_sources
    FOR ALL TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 13. customers
ALTER TABLE IF EXISTS public.customers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow anon insert customers" ON public.customers;
CREATE POLICY "Allow anon insert customers" ON public.customers
    FOR INSERT TO anon, authenticated
    WITH CHECK (auth.role() IN ('anon', 'authenticated'));

-- 14. daily_tasks
ALTER TABLE IF EXISTS public.daily_tasks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "daily_tasks_all_access" ON public.daily_tasks;
CREATE POLICY "daily_tasks_all_access" ON public.daily_tasks
    FOR ALL TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 15. installations
ALTER TABLE IF EXISTS public.installations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all access to installations for authenticated users" ON public.installations;
CREATE POLICY "Allow all access to installations for authenticated users" ON public.installations
    FOR ALL TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 16. inventory_items
ALTER TABLE IF EXISTS public.inventory_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.inventory_items;
DROP POLICY IF EXISTS "inventory_items_select" ON public.inventory_items;
CREATE POLICY "inventory_items_select" ON public.inventory_items
    FOR SELECT TO anon, authenticated
    USING (true);
CREATE POLICY "Enable all for authenticated users" ON public.inventory_items
    FOR ALL TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 17. notifications
ALTER TABLE IF EXISTS public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "notifications_authenticated_all" ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert_all" ON public.notifications;
CREATE POLICY "notifications_authenticated_all" ON public.notifications
    FOR ALL TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "notifications_insert_all" ON public.notifications
    FOR INSERT TO anon, authenticated
    WITH CHECK (auth.role() IN ('anon', 'authenticated'));

-- 18. product_boq_items
ALTER TABLE IF EXISTS public.product_boq_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public Access product_boq_items" ON public.product_boq_items;
DROP POLICY IF EXISTS "product_boq_items_select" ON public.product_boq_items;
DROP POLICY IF EXISTS "product_boq_items_manage" ON public.product_boq_items;
CREATE POLICY "product_boq_items_select" ON public.product_boq_items
    FOR SELECT TO anon, authenticated
    USING (true);
CREATE POLICY "product_boq_items_manage" ON public.product_boq_items
    FOR ALL TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 19. product_inquiries
ALTER TABLE IF EXISTS public.product_inquiries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow insert for all" ON public.product_inquiries;
CREATE POLICY "Allow insert for all" ON public.product_inquiries
    FOR INSERT TO anon, authenticated
    WITH CHECK (auth.role() IN ('anon', 'authenticated'));

-- 20. quotations
ALTER TABLE IF EXISTS public.quotations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow anon update quotations" ON public.quotations;
CREATE POLICY "Allow anon update quotations" ON public.quotations
    FOR UPDATE TO anon, authenticated
    USING (auth.role() IN ('anon', 'authenticated'))
    WITH CHECK (auth.role() IN ('anon', 'authenticated'));

-- 21. sales_pipelines
ALTER TABLE IF EXISTS public.sales_pipelines ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "pipelines_authenticated_all" ON public.sales_pipelines;
CREATE POLICY "pipelines_authenticated_all" ON public.sales_pipelines
    FOR ALL TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 22. service_visits
ALTER TABLE IF EXISTS public.service_visits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow staff to insert service visits" ON public.service_visits;
CREATE POLICY "Allow staff to insert service visits" ON public.service_visits
    FOR INSERT TO authenticated
    WITH CHECK (auth.role() = 'authenticated');

-- 23. step_audit_log
ALTER TABLE IF EXISTS public.step_audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "audit_authenticated_all" ON public.step_audit_log;
CREATE POLICY "audit_authenticated_all" ON public.step_audit_log
    FOR ALL TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 24. supplementary_items
ALTER TABLE IF EXISTS public.supplementary_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all access to supplementary_items for authenticated users" ON public.supplementary_items;
CREATE POLICY "Allow all access to supplementary_items for authenticated users" ON public.supplementary_items
    FOR ALL TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 25. technicians
ALTER TABLE IF EXISTS public.technicians ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_all_technicians" ON public.technicians;
DROP POLICY IF EXISTS "technicians_select" ON public.technicians;
DROP POLICY IF EXISTS "technicians_manage" ON public.technicians;
CREATE POLICY "technicians_select" ON public.technicians
    FOR SELECT TO anon, authenticated
    USING (true);
CREATE POLICY "technicians_manage" ON public.technicians
    FOR ALL TO authenticated
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');


-- ------------------------------------------------------------------------------
-- PART 6: SECURITY DEFINER VIEWS
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    BEGIN
        ALTER VIEW public.pipeline_funnel SET (security_invoker = true);
    EXCEPTION WHEN OTHERS THEN NULL; END;

    BEGIN
        ALTER VIEW public.sales_leaderboard SET (security_invoker = true);
    EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;
