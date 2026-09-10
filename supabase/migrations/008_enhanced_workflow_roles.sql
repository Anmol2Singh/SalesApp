-- ============================================================
-- IZYHEAT Sales App — Migration 008: Enhanced Workflow & Roles
-- ============================================================

-- 1. Alter Enums for Service Head role
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'service_head';
COMMIT;

-- 2. Add tentative_dispatch_date to BOQs and customer_name to customers
ALTER TABLE boqs ADD COLUMN IF NOT EXISTS tentative_dispatch_date TIMESTAMPTZ;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS customer_name TEXT;

-- 3. Add quotation approval tracking fields
ALTER TABLE quotations ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES profiles(id);
ALTER TABLE quotations ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;

-- 4. Add product media columns for gallery images & PDF brochures
ALTER TABLE products ADD COLUMN IF NOT EXISTS image_urls JSONB DEFAULT '[]'::jsonb;
ALTER TABLE products ADD COLUMN IF NOT EXISTS brochure_urls JSONB DEFAULT '[]'::jsonb;

-- 5. Company Settings table for header logo & company defaults
CREATE TABLE IF NOT EXISTS company_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_name TEXT DEFAULT 'INSIYA SOLAR INDUSTRY',
  company_address TEXT,
  company_phone TEXT,
  company_email TEXT,
  company_gst TEXT,
  logo_url TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE company_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all authenticated users to read company settings" ON company_settings;
CREATE POLICY "Allow all authenticated users to read company settings"
  ON company_settings FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow admin to manage company settings" ON company_settings;
CREATE POLICY "Allow admin to manage company settings"
  ON company_settings FOR ALL TO authenticated
  USING (get_my_role()::text = 'admin')
  WITH CHECK (get_my_role()::text = 'admin');

-- 6. Service Visit Spare Parts & Visits Table
CREATE TABLE IF NOT EXISTS service_visits (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contract_id UUID REFERENCES amc_contracts(id),
  pipeline_id UUID REFERENCES sales_pipelines(id),
  customer_id UUID REFERENCES customers(id),
  visit_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  technician_name TEXT,
  service_notes TEXT,
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  labor_charge NUMERIC DEFAULT 0,
  total_cost NUMERIC NOT NULL DEFAULT 0,
  receipt_pdf_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE service_visits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated to read service visits" ON service_visits;
CREATE POLICY "Allow authenticated to read service visits"
  ON service_visits FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow staff to insert service visits" ON service_visits;
CREATE POLICY "Allow staff to insert service visits"
  ON service_visits FOR INSERT TO authenticated WITH CHECK (true);

-- 7. Warranty Cards Table
CREATE TABLE IF NOT EXISTS warranty_cards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pipeline_id UUID REFERENCES sales_pipelines(id),
  customer_id UUID REFERENCES customers(id),
  invoice_number TEXT,
  amc_details TEXT,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ,
  is_activated BOOLEAN DEFAULT false,
  activated_by UUID REFERENCES profiles(id),
  activated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE warranty_cards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all authenticated to read warranty cards" ON warranty_cards;
CREATE POLICY "Allow all authenticated to read warranty cards"
  ON warranty_cards FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow admin & service head to manage warranty cards" ON warranty_cards;
CREATE POLICY "Allow admin & service head to manage warranty cards"
  ON warranty_cards FOR ALL TO authenticated
  USING (get_my_role()::text IN ('admin', 'service_head', 'sales_head'))
  WITH CHECK (get_my_role()::text IN ('admin', 'service_head', 'sales_head'));

-- 8. Product Launches (Customer Marketing Showcase) Table
CREATE TABLE IF NOT EXISTS product_launches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE product_launches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all users to read product launches" ON product_launches;
CREATE POLICY "Allow all users to read product launches"
  ON product_launches FOR SELECT TO authenticated USING (is_active = true OR get_my_role()::text = 'admin');

DROP POLICY IF EXISTS "Allow admin to manage product launches" ON product_launches;
CREATE POLICY "Allow admin to manage product launches"
  ON product_launches FOR ALL TO authenticated
  USING (get_my_role()::text = 'admin')
  WITH CHECK (get_my_role()::text = 'admin');

-- 9. RLS for service_head on pipelines, quotations, boqs
DROP POLICY IF EXISTS pipelines_service_head_all ON sales_pipelines;
CREATE POLICY pipelines_service_head_all ON sales_pipelines
  FOR ALL TO authenticated
  USING (get_my_role()::text = 'service_head' AND deleted_at IS NULL)
  WITH CHECK (get_my_role()::text = 'service_head');

DROP POLICY IF EXISTS quotations_service_head_all ON quotations;
CREATE POLICY quotations_service_head_all ON quotations
  FOR ALL TO authenticated
  USING (get_my_role()::text = 'service_head' AND deleted_at IS NULL)
  WITH CHECK (get_my_role()::text = 'service_head');

-- 10. Storage Buckets Creation & RLS Policies
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('company-assets', 'company-assets', true),
  ('product-images', 'product-images', true),
  ('product-brochures', 'product-brochures', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Allow public read access to company-assets, product-images, product-brochures
DROP POLICY IF EXISTS "Public Read Storage" ON storage.objects;
CREATE POLICY "Public Read Storage"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id IN ('company-assets', 'product-images', 'product-brochures'));

-- Allow authenticated users to upload files to company-assets, product-images, product-brochures
DROP POLICY IF EXISTS "Authenticated Insert Storage" ON storage.objects;
CREATE POLICY "Authenticated Insert Storage"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id IN ('company-assets', 'product-images', 'product-brochures'));

-- Allow authenticated users to update files in company-assets, product-images, product-brochures
DROP POLICY IF EXISTS "Authenticated Update Storage" ON storage.objects;
CREATE POLICY "Authenticated Update Storage"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id IN ('company-assets', 'product-images', 'product-brochures'));

-- Allow authenticated users to delete files in company-assets, product-images, product-brochures
DROP POLICY IF EXISTS "Authenticated Delete Storage" ON storage.objects;
CREATE POLICY "Authenticated Delete Storage"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id IN ('company-assets', 'product-images', 'product-brochures'));

-- 11. Rename company_name to customer_name safely in customers table
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='customers' AND column_name='company_name') 
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='customers' AND column_name='customer_name') THEN
    UPDATE customers SET customer_name = company_name WHERE customer_name IS NULL OR customer_name = '';
    ALTER TABLE customers DROP COLUMN company_name;
  ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='customers' AND column_name='company_name') THEN
    ALTER TABLE customers RENAME COLUMN company_name TO customer_name;
  END IF;
END $$;
