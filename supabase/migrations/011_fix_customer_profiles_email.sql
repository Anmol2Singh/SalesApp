-- Migration: 011_fix_customer_profiles_email.sql
-- Fix: Keep email optional/blank in customer_profiles table if not provided by customer

CREATE OR REPLACE FUNCTION create_auth_user_for_customer()
RETURNS TRIGGER AS $$
DECLARE
  new_user_id UUID;
  fallback_email TEXT;
  customer_display_name TEXT;
  clean_email TEXT;
BEGIN
  -- If phone is empty or null, we cannot create an auth user account
  IF NEW.phone IS NULL OR NEW.phone = '' THEN
    RETURN NEW;
  END IF;

  -- Clean provided email (NULL if empty or whitespace)
  clean_email := NULLIF(TRIM(COALESCE(NEW.email, '')), '');

  -- Check if a user with this phone already exists in auth.users
  SELECT id INTO new_user_id FROM auth.users WHERE phone = NEW.phone LIMIT 1;
  
  -- If not found by phone, check by email if set
  IF new_user_id IS NULL AND clean_email IS NOT NULL THEN
    SELECT id INTO new_user_id FROM auth.users WHERE email = clean_email LIMIT 1;
  END IF;
  
  customer_display_name := COALESCE(NEW.customer_name, NEW.contact_person, NEW.company_name, 'New Customer');

  IF clean_email IS NULL THEN
    fallback_email := NEW.phone || '@izyheat-customer.com';
  ELSE
    fallback_email := clean_email;
  END IF;

  -- If no auth.users record exists, create one with auth fallback email
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
  END IF;

  -- Ensure customer_profiles stores ONLY real email (clean_email), never synthetic email
  INSERT INTO public.customer_profiles (id, full_name, email, phone, updated_at)
  VALUES (
    new_user_id, 
    customer_display_name, 
    clean_email, 
    NEW.phone, 
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET full_name = EXCLUDED.full_name, 
      email = EXCLUDED.email, 
      phone = COALESCE(customer_profiles.phone, EXCLUDED.phone), 
      updated_at = NOW();

  -- Satisfy the created_by constraint on customers table if NULL
  IF NEW.created_by IS NULL THEN
    SELECT id INTO NEW.created_by FROM public.profiles WHERE role = 'admin' AND is_active = true LIMIT 1;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Clean existing synthetic emails or mismatched emails in customer_profiles
UPDATE public.customer_profiles cp
SET email = NULL
FROM public.customers c
WHERE (cp.phone = c.phone OR cp.id = c.id)
  AND (c.email IS NULL OR c.email = '' OR cp.email LIKE '%@izyheat-customer.com');
