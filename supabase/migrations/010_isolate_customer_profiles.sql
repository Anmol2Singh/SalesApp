-- ============================================================
-- Migration 010: Isolate Customer Profiles & Restrict Profiles to Staff Users
-- ============================================================

-- 1. Repoint notifications.user_id foreign key to auth.users so customer notifications do not require a row in profiles
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_user_id_fkey;
ALTER TABLE notifications ADD CONSTRAINT notifications_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- 2. Allow staff users to read customer profiles
DROP POLICY IF EXISTS customer_profiles_staff_select ON customer_profiles;
CREATE POLICY customer_profiles_staff_select ON customer_profiles
  FOR SELECT TO authenticated 
  USING (
    get_my_role() IN ('admin', 'sales_head', 'sales', 'technician', 'manager', 'service_head', 'factory', 'purchase', 'boq')
  );

-- 3. Update get_my_role() to recognise customers from customer_profiles
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS user_role AS $$
DECLARE
  v_role user_role;
BEGIN
  SELECT role INTO v_role FROM profiles WHERE id = auth.uid() AND deleted_at IS NULL LIMIT 1;
  IF v_role IS NOT NULL THEN
    RETURN v_role;
  END IF;
  
  -- Check customer_profiles for customer account
  IF EXISTS (SELECT 1 FROM customer_profiles WHERE id = auth.uid()) THEN
    RETURN 'customer'::user_role;
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- 4. Rewrite handle_new_user() trigger on auth.users:
-- Customers are stored exclusively in customer_profiles.
-- Profiles table is strictly reserved for staff users.
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  assigned_role user_role;
  raw_role_str TEXT;
BEGIN
  raw_role_str := NEW.raw_user_meta_data->>'role';
  
  -- If role is custom or null, determine default
  IF raw_role_str IS NULL THEN
    IF NEW.email IS NULL OR NEW.email = '' OR NEW.email LIKE '%@izyheat-customer.com' THEN
      assigned_role := 'customer'::user_role;
    ELSE
      assigned_role := 'sales'::user_role;
    END IF;
  ELSE
    assigned_role := raw_role_str::user_role;
  END IF;

  -- ONLY insert into profiles if user is STAFF (role != 'customer')
  IF assigned_role != 'customer'::user_role THEN
    INSERT INTO profiles (id, full_name, email, phone, role)
    VALUES (
      NEW.id,
      COALESCE(NEW.raw_user_meta_data->>'full_name', 'New Staff User'),
      NEW.email,
      NEW.phone,
      assigned_role
    )
    ON CONFLICT (id) DO UPDATE
    SET full_name = EXCLUDED.full_name,
        email = COALESCE(profiles.email, EXCLUDED.email),
        phone = COALESCE(profiles.phone, EXCLUDED.phone),
        role = EXCLUDED.role;
  ELSE
    -- If customer, insert ONLY into customer_profiles
    INSERT INTO customer_profiles (id, full_name, phone, email, updated_at)
    VALUES (
      NEW.id,
      COALESCE(NEW.raw_user_meta_data->>'full_name', 'New Customer'),
      NEW.phone,
      NEW.email,
      NOW()
    )
    ON CONFLICT (id) DO UPDATE
    SET full_name = EXCLUDED.full_name,
        phone = COALESCE(customer_profiles.phone, EXCLUDED.phone),
        email = COALESCE(customer_profiles.email, EXCLUDED.email),
        updated_at = NOW();
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Rewrite create_auth_user_for_customer() trigger function on customers table:
-- Inserts customers ONLY into customer_profiles, never into profiles.
CREATE OR REPLACE FUNCTION create_auth_user_for_customer()
RETURNS TRIGGER AS $$
DECLARE
  new_user_id UUID;
  fallback_email TEXT;
  customer_display_name TEXT;
BEGIN
  -- If phone is empty or null, we cannot create an auth user account
  IF NEW.phone IS NULL OR NEW.phone = '' THEN
    RETURN NEW;
  END IF;

  -- Check if a user with this phone already exists in auth.users
  SELECT id INTO new_user_id FROM auth.users WHERE phone = NEW.phone LIMIT 1;
  
  -- If not found by phone, check by email if set
  IF new_user_id IS NULL AND NEW.email IS NOT NULL AND NEW.email != '' THEN
    SELECT id INTO new_user_id FROM auth.users WHERE email = NEW.email LIMIT 1;
  END IF;
  
  customer_display_name := COALESCE(NEW.customer_name, NEW.contact_person, NEW.company_name, 'New Customer');

  IF NEW.email IS NULL OR NEW.email = '' THEN
    fallback_email := NEW.phone || '@izyheat-customer.com';
  ELSE
    fallback_email := NEW.email;
  END IF;

  -- If no auth.users record exists, create one!
  IF new_user_id IS NULL THEN
    new_user_id := gen_random_uuid();
    
    INSERT INTO auth.users (
      id,
      instance_id,
      phone,
      phone_confirmed_at,
      email,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      role,
      aud,
      confirmation_token,
      recovery_token,
      email_change_token_new,
      email_change
    ) VALUES (
      new_user_id,
      '00000000-0000-0000-0000-000000000000',
      NEW.phone,
      NOW(),
      fallback_email,
      NOW(),
      '{"provider": "phone", "providers": ["phone"]}',
      jsonb_build_object('full_name', customer_display_name, 'role', 'customer'),
      NOW(),
      NOW(),
      'authenticated',
      'authenticated',
      '',
      '',
      '',
      ''
    );
  ELSE
    -- If auth user exists, resolve their email
    SELECT email INTO fallback_email FROM auth.users WHERE id = new_user_id;
  END IF;

  -- Ensure customer_profiles has this customer (DO NOT INSERT INTO public.profiles!)
  INSERT INTO public.customer_profiles (id, full_name, email, phone, updated_at)
  VALUES (
    new_user_id, 
    customer_display_name, 
    COALESCE(fallback_email, NEW.email), 
    NEW.phone, 
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET full_name = EXCLUDED.full_name, 
      email = COALESCE(customer_profiles.email, EXCLUDED.email), 
      phone = COALESCE(customer_profiles.phone, EXCLUDED.phone), 
      updated_at = NOW();

  -- Satisfy the created_by constraint on customers table if NULL
  IF NEW.created_by IS NULL THEN
    SELECT id INTO NEW.created_by FROM public.profiles WHERE role = 'admin' AND is_active = true LIMIT 1;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Migrate any existing customer data in profiles into customer_profiles
INSERT INTO public.customer_profiles (id, full_name, email, phone)
SELECT id, full_name, email, phone
FROM public.profiles
WHERE role = 'customer'
ON CONFLICT (id) DO UPDATE
SET full_name = EXCLUDED.full_name,
    email = COALESCE(customer_profiles.email, EXCLUDED.email),
    phone = COALESCE(customer_profiles.phone, EXCLUDED.phone),
    updated_at = NOW();

-- 7. Remove all customer records from profiles table so only staff remain
DELETE FROM public.profiles WHERE role = 'customer';
