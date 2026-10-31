-- Migration 040: Filter active staff profiles
-- Ensures get_all_staff_profiles() excludes soft-deleted, deactivated, or inactive staff profiles

DROP FUNCTION IF EXISTS public.get_all_staff_profiles() CASCADE;

CREATE OR REPLACE FUNCTION public.get_all_staff_profiles()
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  email TEXT,
  phone TEXT,
  role user_role,
  roles user_role[],
  is_active BOOLEAN,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id, 
    p.full_name, 
    p.email, 
    p.phone, 
    p.role, 
    p.roles, 
    p.is_active, 
    p.created_at, 
    p.updated_at
  FROM profiles p
  WHERE p.deleted_at IS NULL
    AND (p.is_active IS NULL OR p.is_active = true)
    AND p.role::text != 'customer'
    AND p.role::text != 'deactivated'
    AND (p.roles IS NULL OR NOT ('deactivated' = ANY(p.roles::text[])))
  ORDER BY p.full_name ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_all_staff_profiles() TO authenticated;
