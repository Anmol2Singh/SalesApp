-- ==============================================================================
-- Migration 033: Customer Supporting Documents (Images & PDFs)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.customer_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  file_url TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL, -- 'pdf' or 'image'
  file_size BIGINT DEFAULT 0,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_customer_documents_customer_id ON public.customer_documents(customer_id);

-- Storage bucket for customer supporting documents
INSERT INTO storage.buckets (id, name, public)
VALUES ('customer-documents', 'customer-documents', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage policies:
-- Authenticated users can view objects
DROP POLICY IF EXISTS "Public access to customer-documents" ON storage.objects;
CREATE POLICY "Public access to customer-documents" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'customer-documents');

DROP POLICY IF EXISTS "Staff can upload to customer-documents" ON storage.objects;
CREATE POLICY "Staff can upload to customer-documents" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'customer-documents');

DROP POLICY IF EXISTS "Staff can delete from customer-documents" ON storage.objects;
CREATE POLICY "Staff can delete from customer-documents" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'customer-documents');

-- RLS on customer_documents table
ALTER TABLE public.customer_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff can select customer documents" ON public.customer_documents;
CREATE POLICY "Staff can select customer documents" ON public.customer_documents
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'sales_head', 'manager')
    )
  );

DROP POLICY IF EXISTS "Staff can insert customer documents" ON public.customer_documents;
CREATE POLICY "Staff can insert customer documents" ON public.customer_documents
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'sales_head', 'manager')
    )
  );

DROP POLICY IF EXISTS "Admin can delete customer documents" ON public.customer_documents;
CREATE POLICY "Admin can delete customer documents" ON public.customer_documents
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );
