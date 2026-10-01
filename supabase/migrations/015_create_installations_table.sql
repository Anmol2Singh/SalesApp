-- ============================================================
-- Migration 015: Create installations table and RLS policies
-- ============================================================

CREATE TABLE IF NOT EXISTS public.installations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_number TEXT NOT NULL UNIQUE,
  customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
  customer_name TEXT NOT NULL,
  customer_phone TEXT,
  customer_address TEXT,
  product_name TEXT,
  has_active_amc BOOLEAN DEFAULT false,
  amc_expiry TEXT,
  priority TEXT NOT NULL DEFAULT 'Medium Priority',
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  technician_id TEXT,
  technician_name TEXT,
  technician_avatar_url TEXT,
  tat_remaining TEXT DEFAULT '48h',
  before_image_url TEXT,
  after_image_url TEXT,
  customer_signature_url TEXT,
  technician_signature_url TEXT,
  seal_number_before TEXT,
  seal_number_after TEXT,
  source TEXT DEFAULT 'staff',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.installations ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users full access to installations
CREATE POLICY "Allow all access to installations for authenticated users"
  ON public.installations
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Index commonly queried columns
CREATE INDEX IF NOT EXISTS idx_installations_status ON public.installations(status);
CREATE INDEX IF NOT EXISTS idx_installations_customer_id ON public.installations(customer_id);
CREATE INDEX IF NOT EXISTS idx_installations_created_at ON public.installations(created_at DESC);
