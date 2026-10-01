-- ============================================================
-- Migration 018: Factory Custom Fields Templates
-- ============================================================

CREATE TABLE IF NOT EXISTS public.factory_custom_fields_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  product_name TEXT,
  fields JSONB NOT NULL DEFAULT '[]'::jsonb,
  section_title TEXT DEFAULT 'Additional Details',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Unique index so each product has one template configuration
CREATE UNIQUE INDEX IF NOT EXISTS idx_factory_custom_fields_product 
  ON public.factory_custom_fields_templates (product_id);

ALTER TABLE public.factory_custom_fields_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all authenticated users to read factory field templates" ON public.factory_custom_fields_templates;
CREATE POLICY "Allow all authenticated users to read factory field templates"
  ON public.factory_custom_fields_templates FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow admin to manage factory field templates" ON public.factory_custom_fields_templates;
CREATE POLICY "Allow admin to manage factory field templates"
  ON public.factory_custom_fields_templates FOR ALL TO authenticated
  USING (get_my_role()::text = 'admin')
  WITH CHECK (get_my_role()::text = 'admin');
