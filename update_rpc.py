import psycopg2

sql = """
CREATE OR REPLACE FUNCTION update_user_roles(
  target_user_id UUID,
  new_roles TEXT[]
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  primary_role TEXT;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND ('admin' = ANY(roles) OR role = 'admin' OR 'manager' = ANY(roles)) AND is_active = true
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Admin access required');
  END IF;

  IF array_length(new_roles, 1) IS NULL OR array_length(new_roles, 1) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'At least one role is required');
  END IF;
  
  primary_role := new_roles[1];

  UPDATE auth.users
  SET 
    raw_user_meta_data = jsonb_set(
      jsonb_set(COALESCE(raw_user_meta_data, '{}'::jsonb), '{role}', to_jsonb(primary_role)),
      '{roles}',
      to_jsonb(new_roles)
    ),
    updated_at = NOW()
  WHERE id = target_user_id;

  UPDATE public.profiles
  SET 
    roles = new_roles,
    role = primary_role::user_role,
    updated_at = NOW()
  WHERE id = target_user_id;

  RETURN jsonb_build_object('success', true);
END;
$$;
"""

conn = psycopg2.connect(
    dbname='postgres',
    user='postgres',
    password='CHTxPuCOTxh2eD5K',
    host='db.dnhbtkhcjpkthvyhyzmt.supabase.co',
    port='5432'
)
cur = conn.cursor()
cur.execute(sql)
conn.commit()
cur.close()
conn.close()
print('RPC updated successfully')
