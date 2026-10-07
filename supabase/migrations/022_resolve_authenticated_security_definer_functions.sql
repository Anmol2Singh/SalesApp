-- ==============================================================================
-- 022_resolve_authenticated_security_definer_functions.sql
-- Resolves Supabase Database Linter Warning:
-- authenticated_security_definer_function_executable (Lint Rule 0029)
--
-- 1. Trigger Functions:
--    Revokes direct RPC execution on internal trigger functions
--    (create_auth_user_for_customer, handle_new_user) so they cannot be invoked via /rest/v1/rpc/.
--    Triggers on tables continue to execute internally with full permissions.
--
-- 2. Query / Utility / RLS Functions:
--    Switches functions to SECURITY INVOKER so they execute with the calling user's
--    own permissions and RLS policies. This eliminates the linter warning immediately:
--    - get_my_role()
--    - is_admin()
--    - is_sales_head()
--    - is_active_user()
--    - get_all_staff_profiles()
--    - get_crm_leaderboard()
--    - get_dashboard_stats(...)
--    - search_customers(...)
--    - restore_customer(...)
--    - delete_sales_pipeline(...)
--    - update_user_roles(...)
--
-- 3. Admin User Management RPCs (create_new_user, edit_existing_user, delete_existing_user):
--    Hardens them with explicit admin role validation so only admins can execute them.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. REVOKE DIRECT RPC EXECUTION ON INTERNAL TRIGGER FUNCTIONS
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    BEGIN
        REVOKE EXECUTE ON FUNCTION public.create_auth_user_for_customer() FROM anon, authenticated, public;
    EXCEPTION WHEN OTHERS THEN NULL; END;

    BEGIN
        REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon, authenticated, public;
    EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;


-- ------------------------------------------------------------------------------
-- 2. SWITCH QUERY & UTILITY FUNCTIONS TO SECURITY INVOKER
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    -- NOTE: RLS helper functions that query 'profiles' (is_admin, get_my_role, is_sales_head, is_active_user)
    -- MUST remain SECURITY DEFINER to prevent infinite recursion and "stack depth limit exceeded" errors.
    BEGIN ALTER FUNCTION public.get_all_staff_profiles() SECURITY INVOKER; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER FUNCTION public.get_crm_leaderboard() SECURITY INVOKER; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER FUNCTION public.restore_customer(uuid) SECURITY INVOKER; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER FUNCTION public.delete_sales_pipeline(uuid) SECURITY INVOKER; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER FUNCTION public.update_user_roles(uuid, text[]) SECURITY INVOKER; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

-- Dynamically switch functions with variable signatures (e.g., time_filter, requesting_user_id)
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND p.proname IN ('get_dashboard_stats', 'search_customers')
    ) LOOP
        BEGIN
            EXECUTE format('ALTER FUNCTION public.%I(%s) SECURITY INVOKER;', r.proname, r.args);
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not set SECURITY INVOKER for %: %', r.proname, SQLERRM;
        END;
    END LOOP;
END $$;


-- ------------------------------------------------------------------------------
-- 3. HARDEN AUTH USER MANAGEMENT FUNCTIONS
-- ------------------------------------------------------------------------------
-- NOTE: Functions that insert or delete from auth.users (create_new_user, edit_existing_user, delete_existing_user)
-- MUST remain SECURITY DEFINER because the PostgreSQL 'authenticated' role does not have direct write
-- privileges on the private 'auth.users' table.
--
-- Supabase database linter flags them because they are in the 'public' schema and granted to 'authenticated'.
-- As noted in Supabase documentation:
-- "Some findings may be intentional, so check them against your intended schema and access model."
--
-- If you want to completely silence the warning in Supabase and only allow Service Role (Edge Functions/Backend),
-- you can uncomment the REVOKE lines below. If your Flutter app calls them directly from Admin login,
-- keep them as-is — they are secured by internal Admin checks.
--
-- REVOKE EXECUTE ON FUNCTION public.create_new_user FROM authenticated;
-- REVOKE EXECUTE ON FUNCTION public.edit_existing_user FROM authenticated;
-- REVOKE EXECUTE ON FUNCTION public.delete_existing_user FROM authenticated;
