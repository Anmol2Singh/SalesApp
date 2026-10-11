-- ============================================================================
-- Manual Cleanup & Remediation Script (DO NOT RUN AUTOMATICALLY)
-- Purpose: Template script to safely remediate any contaminated data found
--          by `db_health_report.sql`. Review each statement before execution.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. PDF TEMPLATES: Remove `generator_company_settings` key without altering
--    existing template configurations used by core quotation PDFs.
-- ----------------------------------------------------------------------------

-- Check current state before change:
SELECT id, document_type, template_config ? 'generator_company_settings' AS has_gen_key
FROM pdf_templates
WHERE document_type = 'quotation';

-- Remove the generator settings key:
UPDATE pdf_templates
SET template_config = template_config - 'generator_company_settings',
    updated_at = NOW()
WHERE document_type = 'quotation'
  AND template_config ? 'generator_company_settings';

-- (Optional) If top-level company details were overwritten and you want to restore
-- original values, uncomment and fill in the values below:
/*
UPDATE pdf_templates
SET template_config = template_config 
    || jsonb_build_object(
        'company_name', 'ORIGINAL_COMPANY_NAME',
        'company_address', 'ORIGINAL_COMPANY_ADDRESS',
        'company_phone', 'ORIGINAL_COMPANY_PHONE',
        'company_email', 'ORIGINAL_COMPANY_EMAIL',
        'company_website', 'ORIGINAL_COMPANY_WEBSITE'
    ),
    updated_at = NOW()
WHERE document_type = 'quotation';
*/

-- ----------------------------------------------------------------------------
-- 2. QUOTATIONS: Remove stuffed generator keys from `product_specs`
--    (Run only after verifying no core deal flow depends on these keys).
-- ----------------------------------------------------------------------------

-- Review rows that have generator keys:
SELECT id, quotation_number, status, product_specs
FROM quotations
WHERE product_specs ? 'generator_quotation';

-- Remove generator-specific keys from product_specs:
/*
UPDATE quotations
SET product_specs = product_specs 
    - 'generator_quotation'
    - 'generator_version'
    - 'quote_type'
    - 'model_name'
    - 'capacity_kw',
    updated_at = NOW()
WHERE product_specs ? 'generator_quotation';
*/

-- ----------------------------------------------------------------------------
-- 3. STORAGE OBJECTS: Review & remove orphan test files from legacy buckets
-- ----------------------------------------------------------------------------

-- Review objects created after the module commit:
SELECT id, name, bucket_id, created_at
FROM storage.objects
WHERE bucket_id IN ('company-assets', 'product-images', 'pdfs')
  AND created_at > '2026-10-11 08:09:24+00'
ORDER BY created_at DESC;

-- Delete orphan test objects (uncomment after inspecting the names above):
/*
DELETE FROM storage.objects
WHERE bucket_id IN ('company-assets', 'product-images', 'pdfs')
  AND created_at > '2026-10-11 08:09:24+00';
*/
