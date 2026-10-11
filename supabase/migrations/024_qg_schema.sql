-- ============================================================================
-- Migration: 024_qg_schema.sql
-- Description: Isolated, additive database objects for the Quotation Generator
--              Proposal PDF module. All objects are strictly prefixed with `qg_`.
--              NO foreign keys to existing tables (plain UUIDs + indexes).
--              Zero modification to core workflows, tables, RLS or triggers.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Tables
-- ----------------------------------------------------------------------------

-- Table: qg_proposals (Approval-gated proposal snapshots)
CREATE TABLE IF NOT EXISTS qg_proposals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quotation_id UUID NOT NULL,
    version INT NOT NULL DEFAULT 1,
    is_current BOOLEAN NOT NULL DEFAULT true,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    source_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
    ref_no TEXT,
    pdf_path TEXT,
    pdf_name TEXT,
    finalized_by UUID,
    finalized_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_qg_proposals_quotation_id ON qg_proposals(quotation_id);
CREATE INDEX IF NOT EXISTS idx_qg_proposals_is_current ON qg_proposals(is_current);

-- Table: qg_catalog (Imported models and specs from reference CSVs)
CREATE TABLE IF NOT EXISTS qg_catalog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kind TEXT NOT NULL, -- 'domestic', 'aio', 'pool'
    model_no TEXT NOT NULL,
    variant_label TEXT NOT NULL,
    kw NUMERIC,
    specs JSONB NOT NULL DEFAULT '{}'::jsonb,
    data_flags JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_qg_catalog_kind_model ON qg_catalog(kind, model_no);
CREATE INDEX IF NOT EXISTS idx_qg_catalog_kw ON qg_catalog(kw);

-- Table: qg_categories (kW ranges & category image mappings)
CREATE TABLE IF NOT EXISTS qg_categories (
    id TEXT PRIMARY KEY, -- 'hp_4_8', 'hp_9_24', 'hp_38_100', 'all_in_one', 'wall_mounted', 'pool', 'other'
    label TEXT NOT NULL,
    min_kw NUMERIC,
    max_kw NUMERIC,
    sort_order INT DEFAULT 0,
    product_image_path TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table: qg_spec_templates (Specification table rows per category)
CREATE TABLE IF NOT EXISTS qg_spec_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id TEXT NOT NULL,
    rows JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_qg_spec_templates_category ON qg_spec_templates(category_id);

-- Table: qg_text_blocks (Verbatim template static texts, admin-customizable)
CREATE TABLE IF NOT EXISTS qg_text_blocks (
    key TEXT PRIMARY KEY,
    text_content TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table: qg_item_aliases (Deal free-text item resolution rules)
CREATE TABLE IF NOT EXISTS qg_item_aliases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pattern TEXT NOT NULL,
    target_type TEXT NOT NULL, -- 'heatPump', 'tank', 'allInOne', 'wallMounted', 'pool', 'supplementary', 'other'
    parsed_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table: qg_settings (Company branding, bank details, defaults, numbering)
CREATE TABLE IF NOT EXISTS qg_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 2. Storage Bucket for Quotation Generator (Private)
-- ----------------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public)
VALUES ('quotation-generator', 'quotation-generator', false)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. Row Level Security (RLS)
-- ----------------------------------------------------------------------------

ALTER TABLE qg_proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE qg_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE qg_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE qg_spec_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE qg_text_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE qg_item_aliases ENABLE ROW LEVEL SECURITY;
ALTER TABLE qg_settings ENABLE ROW LEVEL SECURITY;

-- Helper check function for admin role (strictly admin per requirement)
CREATE OR REPLACE FUNCTION qg_is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND deleted_at IS NULL
      AND (
        role::text = 'admin'
        OR (roles IS NOT NULL AND 'admin' = ANY(roles::text[]))
      )
  );
$$;

-- RLS: qg_proposals
-- Admin can read proposals
DROP POLICY IF EXISTS "Staff can read qg_proposals" ON qg_proposals;
DROP POLICY IF EXISTS "Admin can read qg_proposals" ON qg_proposals;
CREATE POLICY "Admin can read qg_proposals"
ON qg_proposals FOR SELECT
TO authenticated
USING (qg_is_admin());

-- Direct INSERT/UPDATE/DELETE denied for clients (mutations happen strictly via SECURITY DEFINER RPC)
-- (By omitting INSERT/UPDATE/DELETE policies, direct client writes are forbidden)

-- RLS: qg_catalog
DROP POLICY IF EXISTS "Staff can read qg_catalog" ON qg_catalog;
DROP POLICY IF EXISTS "Admin can manage qg_catalog" ON qg_catalog;
CREATE POLICY "Admin can manage qg_catalog"
ON qg_catalog FOR ALL
TO authenticated
USING (qg_is_admin())
WITH CHECK (qg_is_admin());

-- RLS: qg_categories
DROP POLICY IF EXISTS "Staff can read qg_categories" ON qg_categories;
DROP POLICY IF EXISTS "Admin can manage qg_categories" ON qg_categories;
CREATE POLICY "Admin can manage qg_categories"
ON qg_categories FOR ALL
TO authenticated
USING (qg_is_admin())
WITH CHECK (qg_is_admin());

-- RLS: qg_spec_templates
DROP POLICY IF EXISTS "Staff can read qg_spec_templates" ON qg_spec_templates;
DROP POLICY IF EXISTS "Admin can manage qg_spec_templates" ON qg_spec_templates;
CREATE POLICY "Admin can manage qg_spec_templates"
ON qg_spec_templates FOR ALL
TO authenticated
USING (qg_is_admin())
WITH CHECK (qg_is_admin());

-- RLS: qg_text_blocks
DROP POLICY IF EXISTS "Staff can read qg_text_blocks" ON qg_text_blocks;
DROP POLICY IF EXISTS "Admin can manage qg_text_blocks" ON qg_text_blocks;
CREATE POLICY "Admin can manage qg_text_blocks"
ON qg_text_blocks FOR ALL
TO authenticated
USING (qg_is_admin())
WITH CHECK (qg_is_admin());

-- RLS: qg_item_aliases
DROP POLICY IF EXISTS "Staff can read qg_item_aliases" ON qg_item_aliases;
DROP POLICY IF EXISTS "Admin can manage qg_item_aliases" ON qg_item_aliases;
CREATE POLICY "Admin can manage qg_item_aliases"
ON qg_item_aliases FOR ALL
TO authenticated
USING (qg_is_admin())
WITH CHECK (qg_is_admin());

-- RLS: qg_settings
DROP POLICY IF EXISTS "Staff can read qg_settings" ON qg_settings;
DROP POLICY IF EXISTS "Admin can manage qg_settings" ON qg_settings;
CREATE POLICY "Admin can manage qg_settings"
ON qg_settings FOR ALL
TO authenticated
USING (qg_is_admin())
WITH CHECK (qg_is_admin());

-- Storage policies for quotation-generator bucket
DROP POLICY IF EXISTS "Staff can read quotation-generator bucket" ON storage.objects;
DROP POLICY IF EXISTS "Admin can read quotation-generator bucket" ON storage.objects;
CREATE POLICY "Admin can read quotation-generator bucket"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'quotation-generator' AND qg_is_admin());

DROP POLICY IF EXISTS "Staff can upload to proposals folder" ON storage.objects;
DROP POLICY IF EXISTS "Admin can upload to proposals folder" ON storage.objects;
CREATE POLICY "Admin can upload to proposals folder"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'quotation-generator' 
    AND (storage.foldername(name))[1] = 'proposals'
    AND qg_is_admin()
);

-- ----------------------------------------------------------------------------
-- 4. SECURITY DEFINER RPC: qg_finalize_proposal
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION qg_finalize_proposal(
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
DECLARE
    v_user_id UUID;
    v_is_admin BOOLEAN;
    v_quote_status TEXT;
    v_quote_record RECORD;
    v_next_version INT;
    v_new_proposal qg_proposals%ROWTYPE;
    v_snapshot JSONB;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Verify user has admin role
    SELECT qg_is_admin() INTO v_is_admin;
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

    -- Capture snapshot of source quotation
    v_snapshot := jsonb_build_object(
        'quotation_id', v_quote_record.id,
        'quotation_number', v_quote_record.quotation_number,
        'status', v_quote_record.status,
        'updated_at', v_quote_record.updated_at,
        'subtotal', v_quote_record.subtotal,
        'grand_total', v_quote_record.grand_total,
        'snapshot_at', NOW()
    );

    -- Calculate next proposal version
    SELECT COALESCE(MAX(version), 0) + 1
    INTO v_next_version
    FROM qg_proposals
    WHERE quotation_id = p_quotation_id;

    -- Mark prior versions as not current
    UPDATE qg_proposals
    SET is_current = false
    WHERE quotation_id = p_quotation_id;

    -- Insert new proposal version
    INSERT INTO qg_proposals (
        quotation_id,
        version,
        is_current,
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

-- ----------------------------------------------------------------------------
-- 5. Initial Seeds for qg_categories, qg_settings, qg_text_blocks
-- ----------------------------------------------------------------------------

-- Seed categories
INSERT INTO qg_categories (id, label, min_kw, max_kw, sort_order)
VALUES 
    ('hp_4_8', 'Domestic Heat Pump 4 - 8 kW', 4, 8, 1),
    ('hp_9_24', 'Commercial Heat Pump 9 - 24 kW', 9, 24, 2),
    ('hp_38_100', 'Industrial Heat Pump 38 - 100 kW', 38, 100, 3),
    ('all_in_one', 'All in One Floor Mounted', NULL, NULL, 4),
    ('wall_mounted', 'All in One Wall Mounted', NULL, NULL, 5),
    ('pool', 'Swimming Pool Heat Pump', NULL, NULL, 6),
    ('other', 'Other Heat Pump Systems', NULL, NULL, 7)
ON CONFLICT (id) DO NOTHING;

-- Seed default settings
INSERT INTO qg_settings (key, value)
VALUES 
    ('company_details', jsonb_build_object(
        'company_name', 'Insiya Solar Industry',
        'company_address', 'Office No 807, 8th Floor, Finswell Building, Sakore Nagar, Viman Nagar, Pune, Maharashtra 411014',
        'company_phone', '+91 9292922992',
        'company_email', 'sales@insiyasolar.com',
        'company_website', 'www.insiyasolar.com'
    )),
    ('bank_details', jsonb_build_object(
        'bank_name', 'HDFC BANK',
        'account_name', 'INSIYA SOLAR INDUSTRY',
        'account_number', '50200065432109',
        'ifsc_code', 'HDFC0000123',
        'branch', 'VIMAN NAGAR PUNE'
    )),
    ('defaults', jsonb_build_object(
        'ref_number_mode', 'deal_number',
        'legacy_prefix', 'IN/HP/SS',
        'next_running_number', 1,
        'validity_days', 7,
        'tc_item4_status', 'Included',
        'warranty_hp_years', 2,
        'warranty_tank_years', 5,
        'warranty_enamel_years', 15
    )),
    ('tank_presets', jsonb_build_object(
        'GI', jsonb_build_object('shell_thickness', '3mm', 'dish_thickness', '3mm', 'operating_pressure', '6 bar', 'testing_pressure', '9 bar', 'label', 'GI Pressurized Tank'),
        'Enamel', jsonb_build_object('shell_thickness', '2mm', 'dish_thickness', '2mm', 'operating_pressure', '6 bar', 'testing_pressure', '9 bar', 'label', 'Enamel Coated Tank'),
        'MS', jsonb_build_object('shell_thickness', '5mm', 'dish_thickness', '6mm', 'operating_pressure', '6 bar', 'testing_pressure', '9 bar', 'label', 'MS Pressurized Tank'),
        'SS', jsonb_build_object('shell_thickness', '3mm', 'dish_thickness', '3mm', 'operating_pressure', '6 bar', 'testing_pressure', '9 bar', 'label', 'SS 304 Tank', 'is_unconfirmed', true)
    )),
    ('insulation_presets', jsonb_build_object(
        'Puff', '50 mm with Puff Insulation',
        'Rockwool', '100 mm Rockwool Insulation 24 Gauge Aluminium Cladding & other Provisions for stand'
    ))
ON CONFLICT (key) DO NOTHING;

-- Seed static template text blocks (extracted verbatim from Final_Quotation_Template.pdf)
INSERT INTO qg_text_blocks (key, text_content, description)
VALUES 
    ('company_profile_p1', 'We take this opportunity to introduce ourselves as INSIYA SOLAR INDUSTRY engaged in the Design, Engineering, Manufacturing, and Integration of Commercial & Industrial Hot Water Solutions since 2017.', 'Paragraph 1 of company introduction letter'),
    ('company_profile_p2', 'Our heat pump water heaters use advanced eco-friendly technology that absorbs atmospheric heat and transfers it to water, delivering remarkable energy efficiency and operational cost savings.', 'Paragraph 2 of company introduction letter'),
    ('tc_payment_quirk_1', 'wellas', 'Annexure III typo reproduction'),
    ('tc_payment_quirk_2', 'benefitsthat', 'Annexure III typo reproduction'),
    ('tc_payment_quirk_3', 'satisfactoryinstallation', 'Annexure III typo reproduction')
ON CONFLICT (key) DO NOTHING;
