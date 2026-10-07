-- ==============================================================================
-- 023_fix_admin_dashboard_recursion.sql
-- Fixes PostgreSQL Error: "stack depth limit exceeded (code: 54001)"
--
-- ROOT CAUSE:
-- In migration 022, is_admin(), get_my_role(), is_sales_head(), and is_active_user()
-- were switched to SECURITY INVOKER.
-- However, these functions are called inside RLS policies on the 'profiles' table,
-- and their SQL bodies query the 'profiles' table (e.g. SELECT FROM profiles WHERE id = auth.uid()).
-- As SECURITY INVOKER, querying 'profiles' from within an RLS policy on 'profiles'
-- triggers the RLS policy recursively until PostgreSQL exhausts max_stack_depth (2048kB).
--
-- FIX:
-- Restore SECURITY DEFINER on these 4 RLS helper functions.
-- This ensures the internal check on 'profiles' runs with superuser privileges,
-- cleanly bypassing RLS on 'profiles' and preventing infinite recursion.
-- ==============================================================================

DO $$
BEGIN
    BEGIN ALTER FUNCTION public.is_admin() SECURITY DEFINER; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER FUNCTION public.get_my_role() SECURITY DEFINER; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER FUNCTION public.is_sales_head() SECURITY DEFINER; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER FUNCTION public.is_active_user() SECURITY DEFINER; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;
