-- ============================================================================
-- Migration: 026_qg_noc.sql
-- Description: Isolated, additive database objects for the NOC Generator module.
--              Tables: qg_noc_documents, qg_noc_counters, qg_noc_profiles.
--              RPC: qg_finalize_noc (SECURITY DEFINER with strict validation).
--              RLS: Public direct write denied; all writes enforced via RPC.
--              NO foreign keys to existing tables (plain UUIDs).
--              Zero modification to core workflows, tables, RLS or triggers.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Tables
-- ----------------------------------------------------------------------------

-- Table: qg_noc_documents (Issued NOC certificate versions & payload snapshot)
CREATE TABLE IF NOT EXISTS public.qg_noc_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pipeline_id UUID NOT NULL,
    quotation_id UUID,
    customer_id UUID,
    installation_id UUID,
    noc_no TEXT NOT NULL,
    version INT NOT NULL DEFAULT 1,
    is_current BOOLEAN NOT NULL DEFAULT true,
    issued_on DATE NOT NULL DEFAULT CURRENT_DATE,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    pdf_path TEXT,
    pdf_name TEXT,
    override_reason TEXT,
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_qg_noc_documents_pipeline_id ON public.qg_noc_documents(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_qg_noc_documents_noc_no ON public.qg_noc_documents(noc_no);
CREATE INDEX IF NOT EXISTS idx_qg_noc_documents_is_current ON public.qg_noc_documents(is_current);
CREATE INDEX IF NOT EXISTS idx_qg_noc_documents_quotation_id ON public.qg_noc_documents(quotation_id);

-- Table: qg_noc_counters (Race-safe FY counter for NOC numbers)
CREATE TABLE IF NOT EXISTS public.qg_noc_counters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scope TEXT NOT NULL UNIQUE, -- e.g. '26-27'
    last_no INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_qg_noc_counters_scope ON public.qg_noc_counters(scope);

-- Table: qg_noc_profiles (Per-product phrasing, equipment label, confirmations)
CREATE TABLE IF NOT EXISTS public.qg_noc_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_name TEXT NOT NULL UNIQUE,
    equipment_label TEXT NOT NULL,
    work_type_text TEXT NOT NULL,
    wiring_default TEXT NOT NULL DEFAULT 'Done',
    testing_default TEXT NOT NULL DEFAULT 'Done',
    remark_default TEXT NOT NULL DEFAULT 'All Installation & Commissioning work completed as per work order',
    confirmation_lines JSONB NOT NULL DEFAULT '[]'::jsonb,
    closing_sentence TEXT,
    company_name_override TEXT,
    company_address_override TEXT,
    company_email_override TEXT,
    company_mobile_override TEXT,
    company_web_override TEXT,
    logo_url_override TEXT,
    stamp_path_override TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_qg_noc_profiles_product_name ON public.qg_noc_profiles(product_name);

-- ----------------------------------------------------------------------------
-- 2. Seeds: NOC Profiles (Boom Barrier, Heat Pump, Default)
-- ----------------------------------------------------------------------------

INSERT INTO public.qg_noc_profiles (
    product_name,
    equipment_label,
    work_type_text,
    wiring_default,
    testing_default,
    remark_default,
    confirmation_lines,
    closing_sentence
) VALUES
(
    'Boom Barrier',
    'Boom Barrier',
    'Boom Barrier Installation work',
    'Done',
    'Done',
    'All Installation & Commissioning work Completed as per work order',
    '[
        "1. The installation of the Boom Barrier is permitted at the above location.",
        "3. Necessary precautions has been."
    ]'::jsonb,
    'This NOC is issued upon request for installation and operationBoom \nBarrier System.'
),
(
    'Heat Pump',
    'Air Source Heat Pump Water Heating System',
    'Heat Pump Installation work',
    'Done',
    'Done',
    'All Installation & Commissioning work completed as per work order',
    '[
        "1. The installation of the Heat Pump System is permitted at the above location.",
        "2. The installation and commissioning work has been completed as per the work order and to our satisfaction.",
        "3. The Heat Pump System has been tested and handed over in proper working condition.",
        "4. Necessary precautions have been taken during installation and commissioning.",
        "5. We have no objection to the operation of the Heat Pump System at the above location."
    ]'::jsonb,
    'This NOC is issued upon request for installation and operation of the Heat Pump System.'
),
(
    'Default',
    '{Product}',
    '{Product} Installation work',
    'Done',
    'Done',
    'All Installation & Commissioning work completed as per work order',
    '[
        "1. The installation of the {Product} is permitted at the above location.",
        "2. The installation and commissioning work has been completed as per the work order and to our satisfaction.",
        "3. The {Product} has been tested and handed over in proper working condition.",
        "4. Necessary precautions have been taken during installation and commissioning.",
        "5. We have no objection to the operation of the {Product} at the above location."
    ]'::jsonb,
    'This NOC is issued upon request for installation and operation of the {Product} System.'
)
ON CONFLICT (product_name) DO UPDATE SET
    equipment_label = EXCLUDED.equipment_label,
    work_type_text = EXCLUDED.work_type_text,
    wiring_default = EXCLUDED.wiring_default,
    testing_default = EXCLUDED.testing_default,
    remark_default = EXCLUDED.remark_default,
    confirmation_lines = EXCLUDED.confirmation_lines,
    closing_sentence = EXCLUDED.closing_sentence,
    updated_at = NOW();

-- ----------------------------------------------------------------------------
-- 3. Seeds: NOC Text Blocks in qg_text_blocks
-- ----------------------------------------------------------------------------

INSERT INTO public.qg_text_blocks (key, text_content, description) VALUES
('noc_title_line_1', 'NO OBJECTION CERTIFICATE (NOC) FOR {PRODUCT}', 'First line of NOC title (Upper Case)'),
('noc_title_line_2_template', 'SATISFACTORY INSTALLATION & COMMISSION', 'Second line of NOC title in template_exact mode'),
('noc_title_line_2_enhanced', 'SATISFACTORY INSTALLATION & COMMISSIONING', 'Second line of NOC title in enhanced mode'),
('noc_to_salutation', 'The Chairman / Secretary / Sir / Madam', 'Recipient line under To,'),
('noc_subject_template', 'No Objection Certificate for Installation & Commissioning of {Product}.', 'NOC subject line'),
('noc_closing_record_faith', 'This certificate is issued in good faith for record purposes and may be produced wherever required.', 'Enhanced mode closing line'),
('noc_signatory_customer', 'Customer / Authorized Signatory', 'Left signature column header'),
('noc_signatory_company', 'Authorised Signatory', 'Right signature column subheader')
ON CONFLICT (key) DO UPDATE SET
    text_content = EXCLUDED.text_content,
    description = EXCLUDED.description;

-- ----------------------------------------------------------------------------
-- 4. SECURITY DEFINER RPC: qg_finalize_noc
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.qg_finalize_noc(
    p_pipeline_id UUID,
    p_payload JSONB,
    p_pdf_path TEXT,
    p_override_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid UUID;
    v_deal RECORD;
    v_now TIMESTAMPTZ := NOW();
    v_year INT;
    v_month INT;
    v_fy TEXT;
    v_counter INT;
    v_noc_no TEXT;
    v_version INT;
    v_pdf_name TEXT;
    v_new_doc RECORD;
    v_caller_is_admin BOOLEAN := false;
    v_quotation_id UUID;
    v_installation_id UUID;
BEGIN
    -- 1. Ensure authenticated caller
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required to finalize NOC';
    END IF;

    -- Check if caller is admin
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = v_uid AND (role = 'admin' OR 'admin' = ANY(roles))
    ) INTO v_caller_is_admin;

    -- 2. Read deal from sales_pipelines (READ-ONLY)
    SELECT * INTO v_deal
    FROM public.sales_pipelines
    WHERE id = p_pipeline_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Deal with ID % not found', p_pipeline_id;
    END IF;

    -- Fetch associated quotation_id (READ-ONLY)
    SELECT id INTO v_quotation_id
    FROM public.quotations
    WHERE pipeline_id = p_pipeline_id
    LIMIT 1;

    -- 3. Verify deal is 100% complete
    IF v_deal.status <> 'completed' AND COALESCE(v_deal.current_step, '') <> 'completed' THEN
        RAISE EXCEPTION 'Deal is not 100%% complete (current status: %)', v_deal.status;
    END IF;

    -- 4. Find matching resolved/closed installation (READ-ONLY)
    -- Preferred: Explicit link in notes "Deal ID: <pipeline_id>"
    -- Fallback: Same customer_id, product match, created on or after deal creation
    SELECT id INTO v_installation_id
    FROM public.installations
    WHERE (
        notes ILIKE '%Deal ID: ' || p_pipeline_id::text || '%'
        OR (
            customer_id = v_deal.customer_id
            AND created_at >= v_deal.created_at
        )
    )
    AND status IN ('resolved', 'closed')
    ORDER BY created_at DESC
    LIMIT 1;

    -- 5. If installation not found, require Admin Override with non-empty reason
    IF v_installation_id IS NULL THEN
        IF p_override_reason IS NULL OR TRIM(p_override_reason) = '' THEN
            RAISE EXCEPTION 'No eligible resolved/closed installation found for deal. An Admin override reason is required.';
        END IF;

        IF NOT v_caller_is_admin THEN
            RAISE EXCEPTION 'Only an administrator can override the completed installation requirement.';
        END IF;
    END IF;

    -- 6. Compute Financial Year scope (Apr - Mar)
    v_month := EXTRACT(MONTH FROM v_now);
    v_year := EXTRACT(YEAR FROM v_now);
    IF v_month >= 4 THEN
        v_fy := SUBSTRING(v_year::text FROM 3 FOR 2) || '-' || SUBSTRING((v_year + 1)::text FROM 3 FOR 2);
    ELSE
        v_fy := SUBSTRING((v_year - 1)::text FROM 3 FOR 2) || '-' || SUBSTRING(v_year::text FROM 3 FOR 2);
    END IF;

    -- 7. Race-safe counter allocation
    INSERT INTO public.qg_noc_counters (scope, last_no, updated_at)
    VALUES (v_fy, 1, v_now)
    ON CONFLICT (scope)
    DO UPDATE SET
        last_no = public.qg_noc_counters.last_no + 1,
        updated_at = v_now
    RETURNING last_no INTO v_counter;

    -- 8. Assign NOC Number
    v_noc_no := 'NOC/' || v_fy || '/' || LPAD(v_counter::text, 4, '0');

    -- 9. Versioning: flip prior current versions
    SELECT COALESCE(MAX(version), 0) + 1 INTO v_version
    FROM public.qg_noc_documents
    WHERE pipeline_id = p_pipeline_id;

    UPDATE public.qg_noc_documents
    SET is_current = false
    WHERE pipeline_id = p_pipeline_id;

    -- PDF file name
    v_pdf_name := 'NOC_' || REPLACE(v_noc_no, '/', '_') || '_v' || v_version || '.pdf';

    -- 10. Write new NOC record (strictly qg_noc_documents)
    INSERT INTO public.qg_noc_documents (
        pipeline_id,
        quotation_id,
        customer_id,
        installation_id,
        noc_no,
        version,
        is_current,
        issued_on,
        payload,
        pdf_path,
        pdf_name,
        override_reason,
        created_by,
        created_at
    ) VALUES (
        p_pipeline_id,
        v_quotation_id,
        v_deal.customer_id,
        v_installation_id,
        v_noc_no,
        v_version,
        true,
        CURRENT_DATE,
        p_payload,
        p_pdf_path,
        v_pdf_name,
        p_override_reason,
        v_uid,
        v_now
    )
    RETURNING * INTO v_new_doc;

    -- Return newly created document as JSONB
    RETURN to_jsonb(v_new_doc);
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. Row Level Security (RLS)
-- ----------------------------------------------------------------------------

-- Enable RLS
ALTER TABLE public.qg_noc_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qg_noc_counters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qg_noc_profiles ENABLE ROW LEVEL SECURITY;

-- qg_noc_documents:
-- Staff can SELECT documents
DROP POLICY IF EXISTS "qg_noc_documents_select" ON public.qg_noc_documents;
CREATE POLICY "qg_noc_documents_select" ON public.qg_noc_documents
    FOR SELECT TO authenticated
    USING (true);

-- Direct client INSERT/UPDATE/DELETE is explicitly DENIED (must use qg_finalize_noc)
DROP POLICY IF EXISTS "qg_noc_documents_insert_denied" ON public.qg_noc_documents;
CREATE POLICY "qg_noc_documents_insert_denied" ON public.qg_noc_documents
    FOR INSERT TO authenticated
    WITH CHECK (false);

DROP POLICY IF EXISTS "qg_noc_documents_update_denied" ON public.qg_noc_documents;
CREATE POLICY "qg_noc_documents_update_denied" ON public.qg_noc_documents
    FOR UPDATE TO authenticated
    USING (false);

DROP POLICY IF EXISTS "qg_noc_documents_delete_denied" ON public.qg_noc_documents;
CREATE POLICY "qg_noc_documents_delete_denied" ON public.qg_noc_documents
    FOR DELETE TO authenticated
    USING (false);

-- qg_noc_counters:
DROP POLICY IF EXISTS "qg_noc_counters_select" ON public.qg_noc_counters;
CREATE POLICY "qg_noc_counters_select" ON public.qg_noc_counters
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS "qg_noc_counters_write_denied" ON public.qg_noc_counters;
CREATE POLICY "qg_noc_counters_write_denied" ON public.qg_noc_counters
    FOR ALL TO authenticated
    USING (false)
    WITH CHECK (false);

-- qg_noc_profiles:
DROP POLICY IF EXISTS "qg_noc_profiles_select" ON public.qg_noc_profiles;
CREATE POLICY "qg_noc_profiles_select" ON public.qg_noc_profiles
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS "qg_noc_profiles_admin_write" ON public.qg_noc_profiles;
CREATE POLICY "qg_noc_profiles_admin_write" ON public.qg_noc_profiles
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND (role = 'admin' OR 'admin' = ANY(roles))
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND (role = 'admin' OR 'admin' = ANY(roles))
        )
    );

-- ----------------------------------------------------------------------------
-- 6. Storage Bucket Policy: quotation-generator / noc/
-- ----------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects' AND policyname = 'qg_noc_storage_insert'
  ) THEN
    CREATE POLICY "qg_noc_storage_insert" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
      bucket_id = 'quotation-generator'
      AND (storage.foldername(name))[1] = 'noc'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects' AND policyname = 'qg_noc_storage_select'
  ) THEN
    CREATE POLICY "qg_noc_storage_select" ON storage.objects
    FOR SELECT TO authenticated
    USING (
      bucket_id = 'quotation-generator'
      AND (storage.foldername(name))[1] = 'noc'
    );
  END IF;
END $$;
