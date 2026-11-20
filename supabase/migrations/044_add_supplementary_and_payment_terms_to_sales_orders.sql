-- Migration 044: Add supplementary_terms, supplementary_subtotal, payment_terms_stages to sales_orders
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'sales_orders' AND column_name = 'supplementary_terms'
  ) THEN
    ALTER TABLE public.sales_orders ADD COLUMN supplementary_terms JSONB DEFAULT '[]'::jsonb;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'sales_orders' AND column_name = 'supplementary_subtotal'
  ) THEN
    ALTER TABLE public.sales_orders ADD COLUMN supplementary_subtotal NUMERIC DEFAULT 0.0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'sales_orders' AND column_name = 'payment_terms_stages'
  ) THEN
    ALTER TABLE public.sales_orders ADD COLUMN payment_terms_stages JSONB DEFAULT '[]'::jsonb;
  END IF;
END $$;
