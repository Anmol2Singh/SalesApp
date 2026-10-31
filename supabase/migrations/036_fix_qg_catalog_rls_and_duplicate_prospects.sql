-- ============================================================================
-- Migration 036: Fix Quotation Generator RLS for Staff & Prevent Duplicate Prospects
-- ============================================================================

-- ============================================================================
-- PART 1: FIX QUOTATION GENERATOR RLS (Allow Staff/Sales Executive Read Access)
-- ============================================================================

-- 1. qg_catalog: Allow all authenticated users (sales executive, factory, purchase, etc.) to read catalog
DROP POLICY IF EXISTS "Staff can read qg_catalog" ON public.qg_catalog;
CREATE POLICY "Staff can read qg_catalog"
ON public.qg_catalog FOR SELECT
TO authenticated
USING (true);

-- Ensure admin retains full management (INSERT/UPDATE/DELETE/ALL)
DROP POLICY IF EXISTS "Admin can manage qg_catalog" ON public.qg_catalog;
CREATE POLICY "Admin can manage qg_catalog"
ON public.qg_catalog FOR ALL
TO authenticated
USING (public.qg_is_admin())
WITH CHECK (public.qg_is_admin());

-- 2. qg_settings: Allow all authenticated users to read settings (generator_company_settings, bank, etc.)
DROP POLICY IF EXISTS "Staff can read qg_settings" ON public.qg_settings;
CREATE POLICY "Staff can read qg_settings"
ON public.qg_settings FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Admin can manage qg_settings" ON public.qg_settings;
CREATE POLICY "Admin can manage qg_settings"
ON public.qg_settings FOR ALL
TO authenticated
USING (public.qg_is_admin())
WITH CHECK (public.qg_is_admin());

-- 3. qg_categories: Allow all authenticated users to read categories
DROP POLICY IF EXISTS "Staff can read qg_categories" ON public.qg_categories;
CREATE POLICY "Staff can read qg_categories"
ON public.qg_categories FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Admin can manage qg_categories" ON public.qg_categories;
CREATE POLICY "Admin can manage qg_categories"
ON public.qg_categories FOR ALL
TO authenticated
USING (public.qg_is_admin())
WITH CHECK (public.qg_is_admin());

-- 4. qg_spec_templates: Allow all authenticated users to read spec templates
DROP POLICY IF EXISTS "Staff can read qg_spec_templates" ON public.qg_spec_templates;
CREATE POLICY "Staff can read qg_spec_templates"
ON public.qg_spec_templates FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Admin can manage qg_spec_templates" ON public.qg_spec_templates;
CREATE POLICY "Admin can manage qg_spec_templates"
ON public.qg_spec_templates FOR ALL
TO authenticated
USING (public.qg_is_admin())
WITH CHECK (public.qg_is_admin());

-- 5. qg_text_blocks: Allow all authenticated users to read text blocks
DROP POLICY IF EXISTS "Staff can read qg_text_blocks" ON public.qg_text_blocks;
CREATE POLICY "Staff can read qg_text_blocks"
ON public.qg_text_blocks FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Admin can manage qg_text_blocks" ON public.qg_text_blocks;
CREATE POLICY "Admin can manage qg_text_blocks"
ON public.qg_text_blocks FOR ALL
TO authenticated
USING (public.qg_is_admin())
WITH CHECK (public.qg_is_admin());

-- 6. qg_item_aliases: Allow all authenticated users to read aliases
DROP POLICY IF EXISTS "Staff can read qg_item_aliases" ON public.qg_item_aliases;
CREATE POLICY "Staff can read qg_item_aliases"
ON public.qg_item_aliases FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Admin can manage qg_item_aliases" ON public.qg_item_aliases;
CREATE POLICY "Admin can manage qg_item_aliases"
ON public.qg_item_aliases FOR ALL
TO authenticated
USING (public.qg_is_admin())
WITH CHECK (public.qg_is_admin());

-- 7. qg_proposals: Allow staff to read proposals
DROP POLICY IF EXISTS "Staff can read qg_proposals" ON public.qg_proposals;
CREATE POLICY "Staff can read qg_proposals"
ON public.qg_proposals FOR SELECT
TO authenticated
USING (true);

-- 8. Storage bucket 'quotation-generator': Allow all authenticated users to read assets/images/templates
DROP POLICY IF EXISTS "Staff can read quotation-generator bucket" ON storage.objects;
CREATE POLICY "Staff can read quotation-generator bucket"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'quotation-generator');


-- ============================================================================
-- PART 2: PREVENT DUPLICATE PROSPECTS (Normalization, Safety Net, & RPC)
-- ============================================================================

-- 1. Helper Function: normalize_phone
-- Strips non-digits, strips leading '+91', '91' (if 12 digits), and leading '0' (if 11 digits)
CREATE OR REPLACE FUNCTION public.normalize_phone(p_phone TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_digits TEXT;
BEGIN
  IF p_phone IS NULL THEN
    RETURN NULL;
  END IF;

  -- Strip all non-digit characters (spaces, dashes, brackets, etc.)
  v_digits := regexp_replace(p_phone, '\D', '', 'g');

  -- Strip leading 91 if 12 digits (Indian mobile standard)
  IF length(v_digits) = 12 AND v_digits LIKE '91%' THEN
    v_digits := substr(v_digits, 3);
  -- Strip leading 0 if 11 digits
  ELSIF length(v_digits) = 11 AND v_digits LIKE '0%' THEN
    v_digits := substr(v_digits, 2);
  END IF;

  IF v_digits = '' THEN
    RETURN NULL;
  END IF;

  RETURN v_digits;
END;
$$;

-- 2. Helper Function: normalize_name
-- Trims, lowercases, and collapses internal whitespace to a single space
CREATE OR REPLACE FUNCTION public.normalize_name(p_name TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_name IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN regexp_replace(trim(lower(p_name)), '\s+', ' ', 'g');
END;
$$;

-- 3. Add generated column normalized_mobile to crm_prospects
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'crm_prospects' 
      AND column_name = 'normalized_mobile'
  ) THEN
    ALTER TABLE public.crm_prospects 
    ADD COLUMN normalized_mobile TEXT GENERATED ALWAYS AS (public.normalize_phone(phone)) STORED;
  END IF;
END $$;

-- 4. Audit & Safely Handle Existing Duplicates (Detect, Report via NOTICE, Disambiguate without deleting)
DO $$
DECLARE
  rec RECORD;
  dup_count INT := 0;
BEGIN
  -- Report duplicate phones
  FOR rec IN
    SELECT public.normalize_phone(phone) AS norm_phone, count(*) AS cnt, array_agg(id) AS ids, array_agg(name) AS names
    FROM public.crm_prospects
    WHERE phone IS NOT NULL AND public.normalize_phone(phone) IS NOT NULL AND public.normalize_phone(phone) != ''
    GROUP BY public.normalize_phone(phone)
    HAVING count(*) > 1
  LOOP
    dup_count := dup_count + 1;
    RAISE NOTICE 'Existing duplicate mobile detected: phone=%, count=%, names=%, ids=%', rec.norm_phone, rec.cnt, rec.names, rec.ids;
  END LOOP;

  -- Report duplicate names
  FOR rec IN
    SELECT public.normalize_name(name) AS norm_name, count(*) AS cnt, array_agg(id) AS ids, array_agg(phone) AS phones
    FROM public.crm_prospects
    WHERE name IS NOT NULL AND trim(name) != ''
    GROUP BY public.normalize_name(name)
    HAVING count(*) > 1
  LOOP
    dup_count := dup_count + 1;
    RAISE NOTICE 'Existing duplicate name detected: name=%, count=%, phones=%, ids=%', rec.norm_name, rec.cnt, rec.phones, rec.ids;
  END LOOP;

  -- Disambiguate duplicate phones (excluding earliest record) so UNIQUE index can be created safely without losing data
  WITH phone_duplicates AS (
    SELECT id,
           phone,
           ROW_NUMBER() OVER (
             PARTITION BY public.normalize_phone(phone)
             ORDER BY created_at ASC, id ASC
           ) as rn
    FROM public.crm_prospects
    WHERE phone IS NOT NULL AND public.normalize_phone(phone) IS NOT NULL AND public.normalize_phone(phone) != ''
  )
  UPDATE public.crm_prospects p
  SET phone = p.phone || '-dup-' || substr(p.id::text, 1, 8)
  FROM phone_duplicates d
  WHERE p.id = d.id AND d.rn > 1;

  -- Disambiguate duplicate names (excluding earliest record) so UNIQUE index can be created safely without losing data
  WITH name_duplicates AS (
    SELECT id,
           ROW_NUMBER() OVER (
             PARTITION BY public.normalize_name(name)
             ORDER BY created_at ASC, id ASC
           ) as rn
    FROM public.crm_prospects
    WHERE name IS NOT NULL AND trim(name) != ''
  )
  UPDATE public.crm_prospects p
  SET name = p.name || ' (Duplicate ' || substr(p.id::text, 1, 8) || ')'
  FROM name_duplicates d
  WHERE p.id = d.id AND d.rn > 1;
END $$;

-- 5. Database Safety Net: Unique Indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_crm_prospects_unique_normalized_mobile 
ON public.crm_prospects (normalized_mobile) 
WHERE normalized_mobile IS NOT NULL AND normalized_mobile <> '';

CREATE UNIQUE INDEX IF NOT EXISTS idx_crm_prospects_unique_name 
ON public.crm_prospects (public.normalize_name(name)) 
WHERE name IS NOT NULL AND trim(name) <> '';

-- 6. Supabase RPC Function: check_duplicate_prospect
-- SECURITY DEFINER allows company-wide lookup across all prospects bypassing RLS.
-- Returns minimal, non-sensitive data (existing name and owner full name).
CREATE OR REPLACE FUNCTION public.check_duplicate_prospect(
  p_name TEXT,
  p_mobile TEXT,
  p_exclude_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_norm_mobile TEXT;
  v_norm_name TEXT;
  v_dup_phone RECORD;
  v_dup_name RECORD;
BEGIN
  v_norm_mobile := public.normalize_phone(p_mobile);
  v_norm_name := public.normalize_name(p_name);

  -- 1. Check duplicate mobile across company
  IF v_norm_mobile IS NOT NULL AND v_norm_mobile != '' THEN
    SELECT cp.id, cp.name, cp.phone,
           COALESCE(pa.full_name, pc.full_name, 'Unassigned') AS owner_name
    INTO v_dup_phone
    FROM public.crm_prospects cp
    LEFT JOIN public.profiles pa ON pa.id = cp.assigned_to
    LEFT JOIN public.profiles pc ON pc.id = cp.created_by
    WHERE cp.normalized_mobile = v_norm_mobile
      AND (p_exclude_id IS NULL OR cp.id != p_exclude_id)
    LIMIT 1;

    IF v_dup_phone.id IS NOT NULL THEN
      RETURN jsonb_build_object(
        'is_duplicate', true,
        'duplicate_field', 'mobile',
        'existing_name', v_dup_phone.name,
        'existing_owner_name', v_dup_phone.owner_name,
        'message', format('A prospect with this mobile number already exists ("%s", owned by %s)', v_dup_phone.name, v_dup_phone.owner_name)
      );
    END IF;
  END IF;

  -- 2. Check duplicate name across company
  IF v_norm_name IS NOT NULL AND v_norm_name != '' THEN
    SELECT cp.id, cp.name, cp.phone,
           COALESCE(pa.full_name, pc.full_name, 'Unassigned') AS owner_name
    INTO v_dup_name
    FROM public.crm_prospects cp
    LEFT JOIN public.profiles pa ON pa.id = cp.assigned_to
    LEFT JOIN public.profiles pc ON pc.id = cp.created_by
    WHERE public.normalize_name(cp.name) = v_norm_name
      AND (p_exclude_id IS NULL OR cp.id != p_exclude_id)
    LIMIT 1;

    IF v_dup_name.id IS NOT NULL THEN
      RETURN jsonb_build_object(
        'is_duplicate', true,
        'duplicate_field', 'name',
        'existing_name', v_dup_name.name,
        'existing_owner_name', v_dup_name.owner_name,
        'message', format('A prospect with this name already exists ("%s", owned by %s)', v_dup_name.name, v_dup_name.owner_name)
      );
    END IF;
  END IF;

  -- No duplicate found
  RETURN jsonb_build_object(
    'is_duplicate', false,
    'duplicate_field', null,
    'existing_name', null,
    'existing_owner_name', null,
    'message', null
  );
END;
$$;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION public.check_duplicate_prospect(TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.normalize_phone(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.normalize_name(TEXT) TO authenticated;

