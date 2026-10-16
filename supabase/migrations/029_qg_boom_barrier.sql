-- ============================================================================
-- Migration: 029_qg_boom_barrier.sql
-- Description: Isolated, additive schema additions for Boom Barrier quotations
--              under the existing `quotation_generator` module.
--              Strictly module-owned objects (`qg_` prefix, bucket `quotation-generator`).
--              Zero foreign keys to existing tables (plain UUIDs).
--              Zero modifications to legacy tables, core workflows, or Heat Pump output.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Alter qg_proposals: Add template_key with default 'heat_pump_proposal'
-- ----------------------------------------------------------------------------

ALTER TABLE public.qg_proposals 
ADD COLUMN IF NOT EXISTS template_key TEXT NOT NULL DEFAULT 'heat_pump_proposal';

CREATE INDEX IF NOT EXISTS idx_qg_proposals_template_key 
ON public.qg_proposals(template_key);

-- ----------------------------------------------------------------------------
-- 2. Table: qg_product_profiles (Multi-product profile registry)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.qg_product_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    label TEXT NOT NULL,
    match_names TEXT[] NOT NULL DEFAULT '{}',
    template_key TEXT NOT NULL DEFAULT 'boom_barrier_quotation',
    
    -- Company Branding & Header Block
    company_name TEXT NOT NULL DEFAULT 'INSIYA TRADING CORPORATION',
    company_address_lines TEXT[] NOT NULL DEFAULT ARRAY[
        'Office No 807, 8th Floor, Finswell Building',
        'Behind Hyatt Hotel, Viman NagarPune, 411014'
    ],
    company_email TEXT NOT NULL DEFAULT 'insiyaindia@gmail.com    info@insiyacorp.com',
    company_mobile TEXT NOT NULL DEFAULT '+91 7588874019 & +91 9292922992',
    company_website TEXT NOT NULL DEFAULT 'www.insiyacorp.com',
    
    -- Bank Account Details
    bank_name TEXT NOT NULL DEFAULT 'KOTAK MAHINDRA BANK',
    bank_account_name TEXT NOT NULL DEFAULT 'INSIYA TRADING CORPORATION',
    bank_account_no TEXT NOT NULL DEFAULT '9446865227',
    bank_branch TEXT NOT NULL DEFAULT 'VIMAN NAGAR PUNE',
    bank_ifsc TEXT NOT NULL DEFAULT 'KKBK0001804',
    
    -- Assets & Images
    logo_path TEXT NOT NULL DEFAULT 'assets/images/boom_barrier/sefdor_logo.png',
    default_cover_path TEXT NOT NULL DEFAULT 'assets/images/boom_barrier/cover_artwork.png',
    stamp_path TEXT,
    
    -- Quotation Reference & Numbering Strategy
    ref_mode TEXT NOT NULL DEFAULT 'deal_number', -- 'deal_number' | 'legacy_pattern'
    ref_pattern TEXT NOT NULL DEFAULT 'SD/SS/{FY}/{n}',
    next_ref_number INT NOT NULL DEFAULT 442,
    
    -- Number Formatting Strategy
    number_format_mode TEXT NOT NULL DEFAULT 'template_exact', -- 'template_exact' | 'indian_grouping'
    
    -- Default Template Text Lists
    default_terms TEXT[] NOT NULL DEFAULT ARRAY[
        '1. Quotation Validity: 7 Days from the date of submission.',
        '2. Payment Terms: {payment_terms_sentence}',
        '3. Warranty: 2 years on-site warranty against manufacturing defects from the date of handover.',
        '4. Delivery: Within 7 days from the date of confirmed PO with advance payment.',
        '5. Installation: 1-2 Week from the date of delivery and site readiness.',
        '6. Taxes: GST 18% extra as applicable.',
        '7. AMC: Annual Maintenance Contract available @ 15% per annum after warranty expiry.'
    ],
    default_notes TEXT[] NOT NULL DEFAULT ARRAY[
        ': In 100 Meter Civil, Plumber, Earthling, Electrical work done by Clint side.',
        ': 1 Phase 230V AC, 5 Amp with proper earthing Power Supply at Entry Gate/Barrier',
        ': Cabling will be through 25mm 2 kg PVC conduit only.',
        ': Loop wire will be installed in 25mm 6 kg PVC conduit.',
        ': In case of open cabling it will be charged as per actual.',
        ': Any other work apart from the above will be charged extra.',
        ': Standard delivery & installation will depends up on site conditions.'
    ],
    default_at_actual_charges JSONB NOT NULL DEFAULT '[
        {"sr_no": 1, "description": "Wiring charges CAT6 + 3 core Power cable", "qty": "1 mtr", "rate": "150.00", "total": "At Actual"}
    ]'::jsonb,
    
    -- Commercial Defaults
    warranty_years INT NOT NULL DEFAULT 2,
    delivery_days TEXT NOT NULL DEFAULT '7 days',
    installation_period TEXT NOT NULL DEFAULT '1-2 Week',
    onsite_service_period TEXT NOT NULL DEFAULT '1 year',
    amc_rate_percent NUMERIC NOT NULL DEFAULT 15.0,
    
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_qg_product_profiles_key ON public.qg_product_profiles(key);
CREATE INDEX IF NOT EXISTS idx_qg_product_profiles_is_active ON public.qg_product_profiles(is_active);

ALTER TABLE public.qg_product_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff can read qg_product_profiles" ON public.qg_product_profiles;
CREATE POLICY "Staff can read qg_product_profiles"
ON public.qg_product_profiles FOR SELECT
TO authenticated
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Admin can manage qg_product_profiles" ON public.qg_product_profiles;
CREATE POLICY "Admin can manage qg_product_profiles"
ON public.qg_product_profiles FOR ALL
TO authenticated
USING (public.qg_is_admin())
WITH CHECK (public.qg_is_admin());

-- ----------------------------------------------------------------------------
-- 3. Extend qg_catalog: Additional columns for Boom Barrier & Specifications
-- ----------------------------------------------------------------------------

ALTER TABLE public.qg_catalog 
ADD COLUMN IF NOT EXISTS display_name TEXT,
ADD COLUMN IF NOT EXISTS model_type TEXT,
ADD COLUMN IF NOT EXISTS image_path TEXT,
ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS description_title TEXT,
ADD COLUMN IF NOT EXISTS inclusions JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS updated_by UUID,
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;

-- Unique active model index for Boom Barrier
CREATE UNIQUE INDEX IF NOT EXISTS idx_qg_catalog_bb_unique_model 
ON public.qg_catalog (kind, UPPER(TRIM(model_no))) 
WHERE kind = 'boom_barrier' AND archived_at IS NULL;

-- ----------------------------------------------------------------------------
-- 4. Table: qg_model_types (Admin extensible model types e.g. barrier, lpr, turnstile)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.qg_model_types (
    key TEXT PRIMARY KEY,
    label TEXT NOT NULL,
    spec_template_key TEXT NOT NULL,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.qg_model_types ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff can read qg_model_types" ON public.qg_model_types;
CREATE POLICY "Staff can read qg_model_types"
ON public.qg_model_types FOR SELECT
TO authenticated
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Admin can manage qg_model_types" ON public.qg_model_types;
CREATE POLICY "Admin can manage qg_model_types"
ON public.qg_model_types FOR ALL
TO authenticated
USING (public.qg_is_admin())
WITH CHECK (public.qg_is_admin());

-- ----------------------------------------------------------------------------
-- 5. Table: qg_catalog_audit (Append-only audit trail for catalog modifications)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.qg_catalog_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    catalog_id UUID NOT NULL,
    changed_by UUID,
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    action TEXT NOT NULL,
    before_state JSONB,
    after_state JSONB
);

ALTER TABLE public.qg_catalog_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin can read qg_catalog_audit" ON public.qg_catalog_audit;
CREATE POLICY "Admin can read qg_catalog_audit"
ON public.qg_catalog_audit FOR SELECT
TO authenticated
USING (public.qg_is_admin());

-- Trigger function for audit
CREATE OR REPLACE FUNCTION public.qg_trg_catalog_audit_fn()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF (TG_OP = 'DELETE' AND OLD.kind = 'boom_barrier') THEN
        INSERT INTO public.qg_catalog_audit (catalog_id, changed_by, action, before_state, after_state)
        VALUES (OLD.id, auth.uid(), 'DELETE', to_jsonb(OLD), NULL);
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE' AND (NEW.kind = 'boom_barrier' OR OLD.kind = 'boom_barrier')) THEN
        INSERT INTO public.qg_catalog_audit (catalog_id, changed_by, action, before_state, after_state)
        VALUES (NEW.id, auth.uid(), 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT' AND NEW.kind = 'boom_barrier') THEN
        INSERT INTO public.qg_catalog_audit (catalog_id, changed_by, action, before_state, after_state)
        VALUES (NEW.id, auth.uid(), 'INSERT', NULL, to_jsonb(NEW));
        RETURN NEW;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_qg_catalog_audit ON public.qg_catalog;
CREATE TRIGGER trg_qg_catalog_audit
AFTER INSERT OR UPDATE OR DELETE ON public.qg_catalog
FOR EACH ROW EXECUTE FUNCTION public.qg_trg_catalog_audit_fn();

-- ----------------------------------------------------------------------------
-- 6. Storage Policies: Allow Admin upload to catalog/boom_barrier/... in module bucket
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Admin can upload to catalog boom barrier folder" ON storage.objects;
CREATE POLICY "Admin can upload to catalog boom barrier folder"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'quotation-generator' 
    AND name LIKE 'catalog/boom_barrier/%'
    AND public.qg_is_admin()
);

DROP POLICY IF EXISTS "Admin can update in catalog boom barrier folder" ON storage.objects;
CREATE POLICY "Admin can update in catalog boom barrier folder"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'quotation-generator' 
    AND name LIKE 'catalog/boom_barrier/%'
    AND public.qg_is_admin()
)
WITH CHECK (
    bucket_id = 'quotation-generator' 
    AND name LIKE 'catalog/boom_barrier/%'
    AND public.qg_is_admin()
);

-- ----------------------------------------------------------------------------
-- 7. SECURITY DEFINER RPC: Backward-Compatible qg_finalize_proposal Overload
-- ----------------------------------------------------------------------------

-- 5-argument master function (supporting p_template_key)
CREATE OR REPLACE FUNCTION public.qg_finalize_proposal(
    p_quotation_id UUID,
    p_payload JSONB,
    p_pdf_path TEXT,
    p_ref_no TEXT,
    p_template_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_is_admin BOOLEAN;
    v_quote_status TEXT;
    v_quote_record RECORD;
    v_next_version INT;
    v_new_proposal qg_proposals%ROWTYPE;
    v_snapshot JSONB;
    v_template_key TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Verify user has admin role
    SELECT public.qg_is_admin() INTO v_is_admin;
    IF NOT v_is_admin THEN
        RAISE EXCEPTION 'Access denied: Quotation Generator is restricted to admin role.';
    END IF;

    -- Fetch source quotation (read-only verification)
    SELECT id, status, updated_at, grand_total, subtotal, quotation_number
    INTO v_quote_record
    FROM quotations
    WHERE id = p_quotation_id AND deleted_at IS NULL;

    IF v_quote_record.id IS NULL THEN
        RAISE EXCEPTION 'Quotation % not found or deleted', p_quotation_id;
    END IF;

    -- Strict approval gating: status must be 'confirmed'
    v_quote_status := LOWER(TRIM(v_quote_record.status));
    IF v_quote_status != 'confirmed' THEN
        RAISE EXCEPTION 'Approval gating: Proposal cannot be finalized because quotation status is "%". Must be "confirmed".', v_quote_record.status;
    END IF;

    v_template_key := COALESCE(NULLIF(TRIM(p_template_key), ''), 'heat_pump_proposal');

    -- Capture snapshot of source quotation
    v_snapshot := jsonb_build_object(
        'quotation_id', v_quote_record.id,
        'quotation_number', v_quote_record.quotation_number,
        'status', v_quote_record.status,
        'updated_at', v_quote_record.updated_at,
        'subtotal', v_quote_record.subtotal,
        'grand_total', v_quote_record.grand_total,
        'template_key', v_template_key,
        'snapshot_at', NOW()
    );

    -- Calculate next proposal version
    SELECT COALESCE(MAX(version), 0) + 1
    INTO v_next_version
    FROM public.qg_proposals
    WHERE quotation_id = p_quotation_id;

    -- Mark prior versions as not current
    UPDATE public.qg_proposals
    SET is_current = false
    WHERE quotation_id = p_quotation_id;

    -- Insert new proposal version
    INSERT INTO public.qg_proposals (
        quotation_id,
        version,
        is_current,
        template_key,
        payload,
        source_snapshot,
        ref_no,
        pdf_path,
        pdf_name,
        finalized_by,
        finalized_at,
        created_at
    ) VALUES (
        p_quotation_id,
        v_next_version,
        true,
        v_template_key,
        p_payload,
        v_snapshot,
        p_ref_no,
        p_pdf_path,
        p_ref_no || '.pdf',
        v_user_id,
        NOW(),
        NOW()
    )
    RETURNING * INTO v_new_proposal;

    RETURN to_jsonb(v_new_proposal);
END;
$$;

-- 4-argument backward-compatible wrapper (delegating to 5-arg overload)
CREATE OR REPLACE FUNCTION public.qg_finalize_proposal(
    p_quotation_id UUID,
    p_payload JSONB,
    p_pdf_path TEXT,
    p_ref_no TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN public.qg_finalize_proposal(
        p_quotation_id,
        p_payload,
        p_pdf_path,
        p_ref_no,
        'heat_pump_proposal'
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 8. Seed: Model Types, Spec Templates, Product Profile & Catalog Models
-- ----------------------------------------------------------------------------

-- Model types
INSERT INTO public.qg_model_types (key, label, spec_template_key, sort_order)
VALUES 
    ('barrier', 'Boom Barrier', 'bb_barrier', 1),
    ('lpr', 'Number Plate Recognition System (NPRS)', 'bb_lpr', 2),
    ('other', 'Other Access Control', 'bb_other', 3)
ON CONFLICT (key) DO UPDATE SET
    label = EXCLUDED.label,
    spec_template_key = EXCLUDED.spec_template_key,
    sort_order = EXCLUDED.sort_order;

-- Spec templates
INSERT INTO public.qg_spec_templates (id, category_id, rows)
VALUES 
    (
        gen_random_uuid(),
        'bb_barrier',
        '[
            {"label": "Power Supply", "visible": true},
            {"label": "Motor Power", "visible": true},
            {"label": "Boom Length", "visible": true},
            {"label": "RPM", "visible": true},
            {"label": "Remote Distance", "visible": true},
            {"label": "Transmitter", "visible": true},
            {"label": "Working Temp", "visible": true},
            {"label": "Housing Dia", "visible": true},
            {"label": "Weight", "visible": true},
            {"label": "Protection Class", "visible": true}
        ]'::jsonb
    ),
    (
        gen_random_uuid(),
        'bb_lpr',
        '[
            {"label": "Size", "visible": true},
            {"label": "Operating temperature", "visible": true},
            {"label": "Related humidity", "visible": true},
            {"label": "Normal work life", "visible": true},
            {"label": "Power supply", "visible": true},
            {"label": "Operating system", "visible": true},
            {"label": "Power interface", "visible": true},
            {"label": "Identification accuracy", "visible": true},
            {"label": "Voice prompt", "visible": true}
        ]'::jsonb
    )
ON CONFLICT DO NOTHING;

-- Product Profile: Boom Barrier (Insiya Trading Corporation / Sefdor)
INSERT INTO public.qg_product_profiles (
    key,
    label,
    match_names,
    template_key,
    company_name,
    company_address_lines,
    company_email,
    company_mobile,
    company_website,
    bank_name,
    bank_account_name,
    bank_account_no,
    bank_branch,
    bank_ifsc,
    logo_path,
    default_cover_path,
    ref_mode,
    ref_pattern,
    next_ref_number,
    number_format_mode
) VALUES (
    'boom_barrier',
    'Boom Barrier',
    ARRAY['Boom Barrier', 'Boom barrier', 'boom barrier', 'BoomBarrier', 'Barrier'],
    'boom_barrier_quotation',
    'INSIYA TRADING CORPORATION',
    ARRAY[
        'Office No 807, 8th Floor, Finswell Building',
        'Behind Hyatt Hotel, Viman NagarPune, 411014'
    ],
    'insiyaindia@gmail.com    info@insiyacorp.com',
    '+91 7588874019 & +91 9292922992',
    'www.insiyacorp.com',
    'KOTAK MAHINDRA BANK',
    'INSIYA TRADING CORPORATION',
    '9446865227',
    'VIMAN NAGAR PUNE',
    'KKBK0001804',
    'assets/images/boom_barrier/sefdor_logo.png',
    'assets/images/boom_barrier/cover_artwork.png',
    'deal_number',
    'SD/SS/{FY}/{n}',
    442,
    'template_exact'
)
ON CONFLICT (key) DO UPDATE SET
    label = EXCLUDED.label,
    match_names = EXCLUDED.match_names,
    template_key = EXCLUDED.template_key,
    company_name = EXCLUDED.company_name,
    company_address_lines = EXCLUDED.company_address_lines,
    company_email = EXCLUDED.company_email,
    company_mobile = EXCLUDED.company_mobile,
    company_website = EXCLUDED.company_website;

-- Seed Boom Barrier Catalog Models
-- 1. IZ-2001 (Complete specifications)
INSERT INTO public.qg_catalog (
    kind,
    model_no,
    variant_label,
    display_name,
    model_type,
    image_path,
    sort_order,
    description_title,
    inclusions,
    specs,
    data_flags,
    is_active
) VALUES (
    'boom_barrier',
    'IZ-2001',
    'Sefdor Boom Barrier IZ-2001',
    'IZ-2001',
    'barrier',
    'assets/images/boom_barrier/product_iz_2001.png',
    1,
    'Sefdor Boom Barriers Basic Model- IZ-2001',
    '[
        "1)Manual Push Button",
        "2)Remote control with receiver",
        "3)Arm Length -Telescopic"
    ]'::jsonb,
    '{
        "rows": [
            {"label": "Power Supply", "value": "24V/10 AMP", "visible": true},
            {"label": "Motor Power", "value": "90W", "visible": true},
            {"label": "Boom Length", "value": "6M", "visible": true},
            {"label": "RPM", "value": "1500 RPM", "visible": true},
            {"label": "Remote Distance", "value": "6M", "visible": true},
            {"label": "Transmitter", "value": "30M", "visible": true},
            {"label": "Working Temp", "value": "-25°C +60°C", "visible": true},
            {"label": "Housing Dia", "value": "100*34*26", "visible": true},
            {"label": "Weight", "value": "35KG", "visible": true},
            {"label": "Protection Class", "value": "IP55", "visible": true}
        ]
    }'::jsonb,
    '[
        {"flag": "typo_lp55", "note": "Template prints lp55 instead of IP55"}
    ]'::jsonb,
    true
)
ON CONFLICT (kind, UPPER(TRIM(model_no))) WHERE kind = 'boom_barrier' AND archived_at IS NULL
DO UPDATE SET
    display_name = EXCLUDED.display_name,
    model_type = EXCLUDED.model_type,
    image_path = EXCLUDED.image_path,
    sort_order = EXCLUDED.sort_order,
    description_title = EXCLUDED.description_title,
    inclusions = EXCLUDED.inclusions,
    specs = EXCLUDED.specs,
    data_flags = EXCLUDED.data_flags;

-- 2. IZ-2026 (Specs TODO_CONFIRM)
INSERT INTO public.qg_catalog (
    kind,
    model_no,
    variant_label,
    display_name,
    model_type,
    image_path,
    sort_order,
    description_title,
    inclusions,
    specs,
    data_flags,
    is_active
) VALUES (
    'boom_barrier',
    'IZ-2026',
    'Sefdor Boom Barrier IZ-2026',
    'IZ-2026',
    'barrier',
    'assets/images/boom_barrier/product_iz_2026.png',
    2,
    'Sefdor Boom Barriers Basic Model- IZ-2026',
    '[
        "1)Manual Push Button",
        "2)Remote control with receiver",
        "3)Arm Length -Telescopic"
    ]'::jsonb,
    '{
        "rows": [
            {"label": "Power Supply", "value": "", "visible": true},
            {"label": "Motor Power", "value": "", "visible": true},
            {"label": "Boom Length", "value": "", "visible": true},
            {"label": "RPM", "value": "", "visible": true},
            {"label": "Remote Distance", "value": "", "visible": true},
            {"label": "Transmitter", "value": "", "visible": true},
            {"label": "Working Temp", "value": "", "visible": true},
            {"label": "Housing Dia", "value": "", "visible": true},
            {"label": "Weight", "value": "", "visible": true},
            {"label": "Protection Class", "value": "", "visible": true}
        ]
    }'::jsonb,
    '[{"flag": "specs_incomplete", "note": "Specs to be confirmed by admin"}]'::jsonb,
    true
)
ON CONFLICT (kind, UPPER(TRIM(model_no))) WHERE kind = 'boom_barrier' AND archived_at IS NULL
DO UPDATE SET
    display_name = EXCLUDED.display_name,
    model_type = EXCLUDED.model_type,
    image_path = EXCLUDED.image_path,
    sort_order = EXCLUDED.sort_order,
    description_title = EXCLUDED.description_title,
    inclusions = EXCLUDED.inclusions;

-- 3. IZ-2004 (Specs TODO_CONFIRM)
INSERT INTO public.qg_catalog (
    kind,
    model_no,
    variant_label,
    display_name,
    model_type,
    image_path,
    sort_order,
    description_title,
    inclusions,
    specs,
    data_flags,
    is_active
) VALUES (
    'boom_barrier',
    'IZ-2004',
    'Sefdor Boom Barrier IZ-2004',
    'IZ-2004',
    'barrier',
    'assets/images/boom_barrier/product_iz_2004.png',
    3,
    'Sefdor Boom Barriers Basic Model- IZ-2004',
    '[
        "1)Manual Push Button",
        "2)Remote control with receiver",
        "3)Arm Length -Telescopic"
    ]'::jsonb,
    '{
        "rows": [
            {"label": "Power Supply", "value": "", "visible": true},
            {"label": "Motor Power", "value": "", "visible": true},
            {"label": "Boom Length", "value": "", "visible": true},
            {"label": "RPM", "value": "", "visible": true},
            {"label": "Remote Distance", "value": "", "visible": true},
            {"label": "Transmitter", "value": "", "visible": true},
            {"label": "Working Temp", "value": "", "visible": true},
            {"label": "Housing Dia", "value": "", "visible": true},
            {"label": "Weight", "value": "", "visible": true},
            {"label": "Protection Class", "value": "", "visible": true}
        ]
    }'::jsonb,
    '[{"flag": "specs_incomplete", "note": "Specs to be confirmed by admin"}]'::jsonb,
    true
)
ON CONFLICT (kind, UPPER(TRIM(model_no))) WHERE kind = 'boom_barrier' AND archived_at IS NULL
DO UPDATE SET
    display_name = EXCLUDED.display_name,
    model_type = EXCLUDED.model_type,
    image_path = EXCLUDED.image_path,
    sort_order = EXCLUDED.sort_order,
    description_title = EXCLUDED.description_title,
    inclusions = EXCLUDED.inclusions;

-- 4. NPRS / LPR (Specs TODO_CONFIRM)
INSERT INTO public.qg_catalog (
    kind,
    model_no,
    variant_label,
    display_name,
    model_type,
    image_path,
    sort_order,
    description_title,
    inclusions,
    specs,
    data_flags,
    is_active
) VALUES (
    'boom_barrier',
    'NPRS',
    'Number Plate Recognition System (NPRS)',
    'Number Plate Recognition System (NPRS)',
    'lpr',
    'assets/images/boom_barrier/product_nprs.png',
    4,
    'Number Plate Recognition System (NPRS)',
    '[]'::jsonb,
    '{
        "rows": [
            {"label": "Size", "value": "", "visible": true},
            {"label": "Operating temperature", "value": "", "visible": true},
            {"label": "Related humidity", "value": "", "visible": true},
            {"label": "Normal work life", "value": "", "visible": true},
            {"label": "Power supply", "value": "", "visible": true},
            {"label": "Operating system", "value": "", "visible": true},
            {"label": "Power interface", "value": "", "visible": true},
            {"label": "Identification accuracy", "value": "", "visible": true},
            {"label": "Voice prompt", "value": "", "visible": true}
        ]
    }'::jsonb,
    '[{"flag": "specs_incomplete", "note": "LPR specs to be confirmed by admin"}]'::jsonb,
    true
)
ON CONFLICT (kind, UPPER(TRIM(model_no))) WHERE kind = 'boom_barrier' AND archived_at IS NULL
DO UPDATE SET
    display_name = EXCLUDED.display_name,
    model_type = EXCLUDED.model_type,
    image_path = EXCLUDED.image_path,
    sort_order = EXCLUDED.sort_order,
    description_title = EXCLUDED.description_title;

-- Seed Verbatim Static Text Blocks for Boom Barrier (bb_*)
INSERT INTO public.qg_text_blocks (key, text_content, description)
VALUES 
    ('bb_intro_line', 'With reference to your requirement of Barrier for Entry Gate, we are pleased to submit our best offer for the same.', 'Introductory line on Boom Barrier quotation page'),
    ('bb_sub_prefix', 'Quotation for Supply & Installation of Boom Barrier for Entry Gate', 'Subject prefix for Boom Barrier quotation'),
    ('bb_option_title', 'Option 1', 'Option header above price table'),
    ('bb_acceptance_p1', 'With reference to quotation number {ref} dated {date}, with Quotation Value {total}, I''m glad to inform you that your quote has been Approved for the corresponding project, With Term conditions of Payment: {payment_sentence}.', 'Acceptance letter confirmation paragraph'),
    ('bb_acceptance_p2', 'Looking forward to doing business with you.', 'Acceptance letter closing sentence'),
    ('bb_acceptance_closing', 'Yours sincerely,', 'Acceptance letter signoff')
ON CONFLICT (key) DO UPDATE SET
    text_content = EXCLUDED.text_content,
    description = EXCLUDED.description;
