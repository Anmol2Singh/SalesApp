-- ==============================================================================
-- IZYHEAT Sales App — Migration 031: Multi-Company & Product Assignment Support
-- ==============================================================================

-- 1. Table: app_companies
CREATE TABLE IF NOT EXISTS public.app_companies (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  address TEXT DEFAULT '',
  phone TEXT DEFAULT '',
  email TEXT DEFAULT '',
  website TEXT DEFAULT '',
  gstin TEXT DEFAULT '',
  logo_url TEXT,
  stamp_url TEXT,
  bank_name TEXT DEFAULT '',
  bank_account_name TEXT DEFAULT '',
  bank_account_no TEXT DEFAULT '',
  bank_branch TEXT DEFAULT '',
  bank_ifsc TEXT DEFAULT '',
  is_default BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. RLS Policies for app_companies
ALTER TABLE public.app_companies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all users to read app_companies" ON public.app_companies;
CREATE POLICY "Allow all users to read app_companies"
  ON public.app_companies FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow all users to manage app_companies" ON public.app_companies;
CREATE POLICY "Allow all users to manage app_companies"
  ON public.app_companies FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 3. Seed Default Companies (Insiya Solar Industry & Insiya Trading Corporation)
INSERT INTO public.app_companies (
  id, name, address, phone, email, website, gstin, logo_url, stamp_url,
  bank_name, bank_account_name, bank_account_no, bank_branch, bank_ifsc, is_default
) VALUES 
(
  'insiya-solar',
  'INSIYA SOLAR INDUSTRY',
  'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra 411014',
  '+91 9292922992',
  'insiyasolarindustry@gmail.com',
  'www.insiyasolar.com',
  '27CFTPS5292A1ZY',
  'assets/images/logo.png',
  'assets/images/company_stamp.png',
  'HDFC BANK',
  'INSIYA SOLAR INDUSTRY',
  '50200062828292',
  'VIMAN NAGAR PUNE',
  'HDFC0001804',
  true
),
(
  'insiya-trading',
  'INSIYA TRADING CORPORATION',
  'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra 411014',
  '+91 7588874019 & +91 9292922992',
  'insiyaindia@gmail.com    info@insiyacorp.com',
  'www.insiyacorp.com',
  '27CFTPS5292A1ZY',
  'assets/images/boom_barrier/sefdor_logo.png',
  'assets/images/company_stamp.png',
  'KOTAK MAHINDRA BANK',
  'INSIYA TRADING CORPORATION',
  '9446865227',
  'VIMAN NAGAR PUNE',
  'KKBK0001804',
  false
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  address = EXCLUDED.address,
  phone = EXCLUDED.phone,
  email = EXCLUDED.email,
  website = EXCLUDED.website,
  gstin = EXCLUDED.gstin,
  bank_name = EXCLUDED.bank_name,
  bank_account_name = EXCLUDED.bank_account_name,
  bank_account_no = EXCLUDED.bank_account_no,
  bank_branch = EXCLUDED.bank_branch,
  bank_ifsc = EXCLUDED.bank_ifsc;

-- 4. Add company_id column to products table
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES public.app_companies(id) ON DELETE SET NULL;

-- 5. Auto-link Boom Barrier to insiya-trading and others to insiya-solar
UPDATE public.products 
SET company_id = 'insiya-trading'
WHERE (LOWER(name) LIKE '%boom%' OR LOWER(name) LIKE '%barrier%') AND (company_id IS NULL OR company_id = '');

UPDATE public.products 
SET company_id = 'insiya-solar'
WHERE company_id IS NULL OR company_id = '';
