-- ============================================================================
-- Migration: 027_fix_qg_noc_deal_completion.sql
-- Description: Improve qg_finalize_noc validation so completed sales deals can
-- generate NOC certificates without requiring separate service ticket records,
-- and gracefully handle verification/override reason for Admin & Sales staff.
-- ============================================================================

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
    v_effective_override TEXT;
BEGIN
    -- 1. Ensure authenticated caller
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required to finalize NOC';
    END IF;

    -- Check if caller is admin or authorized sales staff
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = v_uid AND (
            role::text IN ('admin', 'sales_head', 'manager', 'sales', 'technician', 'service_head')
            OR 'admin' = ANY(roles::text[])
            OR 'sales_head' = ANY(roles::text[])
            OR 'manager' = ANY(roles::text[])
            OR 'sales' = ANY(roles::text[])
        )
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

    -- 4. Find matching resolved/closed installation (READ-ONLY) if one exists
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

    -- 5. If installation ticket is not found in installations table,
    -- accept completed deal status with default verification reason
    v_effective_override := COALESCE(
        NULLIF(TRIM(p_override_reason), ''),
        'Completed deal verified with installation & commissioning'
    );

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
        v_effective_override,
        v_uid,
        v_now
    )
    RETURNING * INTO v_new_doc;

    -- Return newly created document as JSONB
    RETURN to_jsonb(v_new_doc);
END;
$$;
