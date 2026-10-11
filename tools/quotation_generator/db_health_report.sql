-- ============================================================================
-- DB Health Report for Quotation Generator Module (READ-ONLY AUDIT)
-- Purpose: Inspect whether any previous runs of the module wrote to core
--          tables (`quotations`, `pdf_templates`) or legacy storage buckets.
-- Date of first module commit (3fc49b6): 2026-10-11T13:39:24+05:30 (08:09:24Z)
-- ============================================================================

-- 1. Check if any rows in `quotations` have generator data injected into `product_specs`
SELECT 
    id, 
    quotation_number, 
    created_at, 
    status 
FROM quotations 
WHERE product_specs ? 'generator_quotation';

-- 2. Check if the core `pdf_templates` quotation row was modified with generator settings
SELECT 
    id, 
    document_type, 
    updated_at, 
    template_config ? 'generator_company_settings' AS has_generator_keys, 
    template_config->>'company_name' AS company_name, 
    template_config->>'company_address' AS company_address 
FROM pdf_templates 
WHERE document_type = 'quotation';

-- 3. Check if any storage files were uploaded by the module to existing buckets
-- Note: 'pdfs' bucket may or may not exist in storage.buckets
SELECT 
    name, 
    bucket_id,
    created_at 
FROM storage.objects 
WHERE bucket_id IN ('company-assets', 'product-images', 'pdfs') 
  AND created_at > '2026-10-11 08:09:24+00' 
ORDER BY created_at DESC;
