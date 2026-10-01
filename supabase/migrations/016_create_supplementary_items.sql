-- ============================================================
-- Migration 016: Create supplementary_items table and quotation additions
-- ============================================================

CREATE TABLE IF NOT EXISTS public.supplementary_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  rate NUMERIC NOT NULL DEFAULT 0.0,
  gst_percent NUMERIC NOT NULL DEFAULT 18.0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.supplementary_items ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users full access
CREATE POLICY "Allow all access to supplementary_items for authenticated users"
  ON public.supplementary_items
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Add supplementary_terms column to quotations table if not present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'quotations' AND column_name = 'supplementary_terms'
  ) THEN
    ALTER TABLE public.quotations ADD COLUMN supplementary_terms JSONB DEFAULT '[]'::jsonb;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'quotations' AND column_name = 'supplementary_subtotal'
  ) THEN
    ALTER TABLE public.quotations ADD COLUMN supplementary_subtotal NUMERIC DEFAULT 0.0;
  END IF;
END $$;
