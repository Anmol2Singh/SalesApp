-- ============================================================
-- IZYHEAT Sales App — Migration 006: Dynamic Workflows & Theme Preferences
-- ============================================================

-- 1. Alter Enums (Adding user_role values)
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'customer';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'boq';

-- 2. Alter profiles table
ALTER TABLE profiles ALTER COLUMN email DROP NOT NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS theme_preference TEXT DEFAULT 'system';

-- 3. Create customer_profiles table
CREATE TABLE IF NOT EXISTS customer_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  theme_preference TEXT DEFAULT 'system',
  saved_addresses JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS on customer_profiles
ALTER TABLE customer_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS customer_profiles_select_own ON customer_profiles;
CREATE POLICY customer_profiles_select_own ON customer_profiles
  FOR SELECT TO authenticated USING (id = auth.uid());

DROP POLICY IF EXISTS customer_profiles_update_own ON customer_profiles;
CREATE POLICY customer_profiles_update_own ON customer_profiles
  FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS customer_profiles_admin_all ON customer_profiles;
CREATE POLICY customer_profiles_admin_all ON customer_profiles
  FOR ALL TO authenticated USING (get_my_role() IN ('admin', 'sales_head')) WITH CHECK (get_my_role() IN ('admin', 'sales_head'));

-- 4. Create workflow_definitions table
CREATE TABLE IF NOT EXISTS workflow_definitions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  steps JSONB NOT NULL DEFAULT '[]', -- [{ "key": "quotation", "name": "Quotation", "owner_role": "sales", "generate_pdf": true }]
  version INT NOT NULL DEFAULT 1,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(product_id, version)
);

-- Enable RLS on workflow_definitions
ALTER TABLE workflow_definitions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS workflow_definitions_read ON workflow_definitions;
CREATE POLICY workflow_definitions_read ON workflow_definitions
  FOR SELECT TO authenticated USING (is_active = TRUE);

DROP POLICY IF EXISTS workflow_definitions_admin_write ON workflow_definitions;
CREATE POLICY workflow_definitions_admin_write ON workflow_definitions
  FOR ALL TO authenticated USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');

-- 5. Alter sales_pipelines table (drop views and policies first)
DROP VIEW IF EXISTS pipeline_funnel;
DROP VIEW IF EXISTS sales_leaderboard;
DROP POLICY IF EXISTS pipelines_factory_read ON sales_pipelines;
DROP POLICY IF EXISTS pipelines_purchase_read ON sales_pipelines;
DROP POLICY IF EXISTS audit_log_factory_read ON step_audit_log;

ALTER TABLE sales_pipelines ALTER COLUMN current_step DROP DEFAULT;
ALTER TABLE sales_pipelines ALTER COLUMN current_step TYPE TEXT USING current_step::TEXT;
ALTER TABLE sales_pipelines ALTER COLUMN current_step SET DEFAULT 'quotation';

-- Add steps_config column
ALTER TABLE sales_pipelines ADD COLUMN IF NOT EXISTS steps_config JSONB;

-- Recreate views
CREATE OR REPLACE VIEW pipeline_funnel AS
SELECT
  current_step,
  COUNT(*) AS count
FROM sales_pipelines
WHERE status != 'cancelled' AND deleted_at IS NULL
GROUP BY current_step;

CREATE OR REPLACE VIEW sales_leaderboard AS
SELECT
  p.id AS salesperson_id,
  p.full_name,
  COUNT(DISTINCT sp.id) FILTER (WHERE sp.current_step = 'completed' OR sp.status = 'completed') AS completed_pipelines,
  COUNT(DISTINCT q.id) FILTER (WHERE q.status = 'confirmed') AS confirmed_quotations,
  COUNT(DISTINCT sp.id) AS total_pipelines
FROM profiles p
LEFT JOIN sales_pipelines sp ON sp.created_by = p.id AND sp.deleted_at IS NULL
LEFT JOIN quotations q ON q.pipeline_id = sp.id AND q.deleted_at IS NULL
WHERE p.role = 'sales' AND p.deleted_at IS NULL
GROUP BY p.id, p.full_name;

-- Recreate policies
CREATE POLICY pipelines_factory_read ON sales_pipelines
  FOR SELECT
  TO authenticated
  USING (
    get_my_role() = 'factory'
    AND current_step IN ('factory_order', 'purchase_order', 'completed')
    AND deleted_at IS NULL
  );

CREATE POLICY pipelines_purchase_read ON sales_pipelines
  FOR SELECT
  TO authenticated
  USING (
    get_my_role() = 'purchase'
    AND current_step IN ('purchase_order', 'completed')
    AND deleted_at IS NULL
  );

CREATE POLICY audit_log_factory_read ON step_audit_log
  FOR SELECT
  TO authenticated
  USING (
    get_my_role() = 'factory'
    AND pipeline_id IN (
      SELECT id FROM sales_pipelines
      WHERE current_step IN ('factory_order', 'purchase_order', 'completed') AND deleted_at IS NULL
    )
  );

-- 6. Rewrite trigger function to handle new auth users
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  assigned_role user_role;
  raw_role_str TEXT;
BEGIN
  raw_role_str := NEW.raw_user_meta_data->>'role';
  
  -- If role is custom or null, determine default
  IF raw_role_str IS NULL THEN
    IF NEW.email IS NULL OR NEW.email = '' THEN
      assigned_role := 'customer'::user_role;
    ELSE
      assigned_role := 'sales'::user_role;
    END IF;
  ELSE
    assigned_role := raw_role_str::user_role;
  END IF;

  -- Insert into profiles
  INSERT INTO profiles (id, full_name, email, phone, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'New User'),
    NEW.email,
    NEW.phone,
    assigned_role
  )
  ON CONFLICT (id) DO UPDATE
  SET full_name = EXCLUDED.full_name,
      email = COALESCE(profiles.email, EXCLUDED.email),
      phone = COALESCE(profiles.phone, EXCLUDED.phone),
      role = EXCLUDED.role;

  -- If customer, also insert/update customer_profiles
  IF assigned_role = 'customer'::user_role THEN
    INSERT INTO customer_profiles (id, full_name, phone, email)
    VALUES (
      NEW.id,
      COALESCE(NEW.raw_user_meta_data->>'full_name', 'New Customer'),
      NEW.phone,
      NEW.email
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Seed default workflows for existing products
DO $$
DECLARE
  prod_rec RECORD;
  default_steps JSONB;
BEGIN
  default_steps := '[
    {"key": "quotation", "name": "Quotation", "owner_role": "sales", "generate_pdf": true},
    {"key": "sales_order", "name": "Sales Order", "owner_role": "sales", "generate_pdf": true},
    {"key": "boq", "name": "BOQ", "owner_role": "sales", "generate_pdf": true},
    {"key": "factory_order", "name": "Factory Order", "owner_role": "factory", "generate_pdf": true},
    {"key": "purchase_order", "name": "Purchase Order", "owner_role": "purchase", "generate_pdf": true}
  ]'::jsonb;

  FOR prod_rec IN SELECT id FROM products LOOP
    INSERT INTO workflow_definitions (product_id, steps, version, is_active)
    VALUES (prod_rec.id, default_steps, 1, TRUE)
    ON CONFLICT (product_id, version) DO NOTHING;
  END LOOP;
END;
$$;

-- Populate steps_config for existing sales_pipelines
UPDATE sales_pipelines
SET steps_config = '[
  {"key": "quotation", "name": "Quotation", "owner_role": "sales", "generate_pdf": true},
  {"key": "sales_order", "name": "Sales Order", "owner_role": "sales", "generate_pdf": true},
  {"key": "boq", "name": "BOQ", "owner_role": "sales", "generate_pdf": true},
  {"key": "factory_order", "name": "Factory Order", "owner_role": "factory", "generate_pdf": true},
  {"key": "purchase_order", "name": "Purchase Order", "owner_role": "purchase", "generate_pdf": true}
]'::jsonb
WHERE steps_config IS NULL;

-- 8. Clean up demo and seeded data
DELETE FROM step_audit_log WHERE amc_contract_id IN (
  SELECT id FROM amc_contracts WHERE amc_number LIKE 'TEST/AMC/%' OR customer_id IN (
    SELECT id FROM customers WHERE company_name IN ('TestCustomer', 'Acme', 'VTP') OR phone = '+919999999999'
  )
);

DELETE FROM notifications WHERE related_amc_id IN (
  SELECT id FROM amc_contracts WHERE amc_number LIKE 'TEST/AMC/%' OR customer_id IN (
    SELECT id FROM customers WHERE company_name IN ('TestCustomer', 'Acme', 'VTP') OR phone = '+919999999999'
  )
);

DELETE FROM amc_service_visits WHERE amc_contract_id IN (
  SELECT id FROM amc_contracts WHERE amc_number LIKE 'TEST/AMC/%' OR customer_id IN (
    SELECT id FROM customers WHERE company_name IN ('TestCustomer', 'Acme', 'VTP') OR phone = '+919999999999'
  )
);

DELETE FROM amc_contracts WHERE amc_number LIKE 'TEST/AMC/%' OR customer_id IN (
  SELECT id FROM customers WHERE company_name IN ('TestCustomer', 'Acme', 'VTP') OR phone = '+919999999999'
);

DELETE FROM notifications WHERE related_pipeline_id IN (
  SELECT id FROM sales_pipelines WHERE customer_id IN (
    SELECT id FROM customers WHERE company_name IN ('TestCustomer', 'Acme', 'VTP') OR phone = '+919999999999'
  )
);

DELETE FROM step_audit_log WHERE pipeline_id IN (
  SELECT id FROM sales_pipelines WHERE customer_id IN (
    SELECT id FROM customers WHERE company_name IN ('TestCustomer', 'Acme', 'VTP') OR phone = '+919999999999'
  )
);

DELETE FROM quotations WHERE pipeline_id IN (
  SELECT id FROM sales_pipelines WHERE customer_id IN (
    SELECT id FROM customers WHERE company_name IN ('TestCustomer', 'Acme', 'VTP') OR phone = '+919999999999'
  )
);

DELETE FROM boqs WHERE pipeline_id IN (
  SELECT id FROM sales_pipelines WHERE customer_id IN (
    SELECT id FROM customers WHERE company_name IN ('TestCustomer', 'Acme', 'VTP') OR phone = '+919999999999'
  )
);

DELETE FROM factory_orders WHERE pipeline_id IN (
  SELECT id FROM sales_pipelines WHERE customer_id IN (
    SELECT id FROM customers WHERE company_name IN ('TestCustomer', 'Acme', 'VTP') OR phone = '+919999999999'
  )
);

DELETE FROM purchase_orders WHERE pipeline_id IN (
  SELECT id FROM sales_pipelines WHERE customer_id IN (
    SELECT id FROM customers WHERE company_name IN ('TestCustomer', 'Acme', 'VTP') OR phone = '+919999999999'
  )
);

DELETE FROM sales_pipelines WHERE customer_id IN (
  SELECT id FROM customers WHERE company_name IN ('TestCustomer', 'Acme', 'VTP') OR phone = '+919999999999'
);

DELETE FROM customers WHERE company_name IN ('TestCustomer', 'Acme', 'VTP') OR phone = '+919999999999';

-- 9. Correct the customer account role
UPDATE profiles
SET role = 'customer'::user_role
WHERE id = 'e0dfc440-97e4-426a-a435-a9ae81b7abf1';

INSERT INTO customer_profiles (id, full_name, phone, email)
VALUES ('e0dfc440-97e4-426a-a435-a9ae81b7abf1', 'Customer (+919999999999)', '+919999999999', '+919999999999@izyheat-customer.com')
ON CONFLICT (id) DO NOTHING;
