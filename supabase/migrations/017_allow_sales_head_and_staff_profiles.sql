-- ============================================================
-- Migration 017: Allow Sales Head, Admin and Staff to view Staff Profiles
-- ============================================================

-- 1. Grant SELECT on profiles to all authenticated staff members
-- so Sales Head, Admin, and team members can view activity reports and assign leads
DROP POLICY IF EXISTS profiles_staff_read ON profiles;
CREATE POLICY profiles_staff_read ON profiles
  FOR SELECT TO authenticated
  USING (
    id = auth.uid() 
    OR get_my_role() IN ('admin', 'sales_head', 'manager', 'sales', 'technician', 'service_head', 'factory', 'purchase', 'boq')
  );

-- 2. Create a SECURITY DEFINER RPC function get_all_staff_profiles()
-- Ensures that sales heads and admins can reliably retrieve the complete list of staff profiles
CREATE OR REPLACE FUNCTION get_all_staff_profiles()
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
    AND p.role != 'customer'
  ORDER BY p.full_name ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_all_staff_profiles() TO authenticated;
