-- ============================================================
-- IZYHEAT Sales App — Migration 037:
-- 1. Quotation Approval Tracking (approved_by, approved_at)
-- 2. App Configuration table (app_config) & Audit (app_config_audit)
-- 3. Global Product-Add Lock Database Enforcement (Trigger & RLS)
-- ============================================================

-- ─── 1. QUOTATION APPROVAL TRACKING ──────────────────────────────────────────

ALTER TABLE quotations ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES profiles(id);
ALTER TABLE quotations ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;

-- Backfill existing confirmed quotations so historical data is consistent
UPDATE quotations
SET approved_by = confirmed_by,
    approved_at = confirmed_at
WHERE approved_by IS NULL AND confirmed_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_quotations_approved_at ON quotations(approved_at DESC);
CREATE INDEX IF NOT EXISTS idx_quotations_approved_by ON quotations(approved_by);

-- ─── 2. APP CONFIGURATION & AUDIT ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS app_config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL DEFAULT 'false'::jsonb,
  expires_at TIMESTAMPTZ,
  auto_lock_mode TEXT DEFAULT 'first_product', -- 'first_product', '15m', '1h', 'off'
  updated_by UUID REFERENCES profiles(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Default row: Product addition locked by default company-wide
INSERT INTO app_config (key, value, auto_lock_mode, updated_at)
VALUES ('product_add_unlocked', 'false'::jsonb, 'first_product', NOW())
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS app_config_audit (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  config_key TEXT NOT NULL,
  old_value JSONB,
  new_value JSONB,
  changed_by UUID REFERENCES profiles(id),
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_app_config_audit_key ON app_config_audit(config_key, changed_at DESC);

-- Trigger to record every config change in app_config_audit
CREATE OR REPLACE FUNCTION audit_app_config_changes()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO app_config_audit (config_key, old_value, new_value, changed_by, changed_at, reason)
  VALUES (
    NEW.key,
    CASE WHEN TG_OP = 'UPDATE' THEN OLD.value ELSE NULL END,
    NEW.value,
    NEW.updated_by,
    NEW.updated_at,
    COALESCE(NEW.auto_lock_mode, 'Updated configuration')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_app_config_audit ON app_config;
CREATE TRIGGER trg_app_config_audit
  AFTER INSERT OR UPDATE ON app_config
  FOR EACH ROW EXECUTE FUNCTION audit_app_config_changes();

-- RLS on app_config
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated read app_config" ON app_config;
CREATE POLICY "Allow authenticated read app_config"
  ON app_config FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow admin modify app_config" ON app_config;
CREATE POLICY "Allow admin modify app_config"
  ON app_config FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND (role = 'admin' OR 'admin' = ANY(roles))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND (role = 'admin' OR 'admin' = ANY(roles))
    )
  );

-- RLS on app_config_audit (Admin read-only, modified only via SECURITY DEFINER trigger)
ALTER TABLE app_config_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow admin read app_config_audit" ON app_config_audit;
CREATE POLICY "Allow admin read app_config_audit"
  ON app_config_audit FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND (role = 'admin' OR 'admin' = ANY(roles))
    )
  );

-- Add app_config to Supabase Realtime publication
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE app_config;
    EXCEPTION WHEN duplicate_object THEN
      -- Already added
    END;
  END IF;
END $$;

-- ─── 3. DATABASE LEVEL LOCK ENFORCEMENT ON PRODUCTS ──────────────────────────

CREATE OR REPLACE FUNCTION check_product_add_lock()
RETURNS TRIGGER AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_unlocked BOOLEAN;
  v_expires_at TIMESTAMPTZ;
  v_auto_lock_mode TEXT;
BEGIN
  -- 1. Verify admin role
  v_is_admin := (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND (role = 'admin' OR 'admin' = ANY(roles))
    )
  );

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'PRODUCT_ADD_LOCKED: Only administrators can add products.';
  END IF;

  -- 2. Query lock state from app_config
  SELECT (value = 'true'::jsonb), expires_at, auto_lock_mode
  INTO v_unlocked, v_expires_at, v_auto_lock_mode
  FROM app_config
  WHERE key = 'product_add_unlocked';

  IF v_unlocked IS NOT TRUE THEN
    RAISE EXCEPTION 'PRODUCT_ADD_LOCKED: Adding products is currently locked. Please unlock in Admin > Configuration.';
  END IF;

  -- 3. Check server-side expiration if configured
  IF v_expires_at IS NOT NULL AND v_expires_at < NOW() THEN
    UPDATE app_config
    SET value = 'false'::jsonb,
        expires_at = NULL,
        updated_at = NOW()
    WHERE key = 'product_add_unlocked';
    RAISE EXCEPTION 'PRODUCT_ADD_LOCKED: The unlock session has expired. Please unlock again in Admin > Configuration.';
  END IF;

  -- 4. If auto_lock_mode is 'first_product', re-lock immediately after this product insert
  IF v_auto_lock_mode = 'first_product' THEN
    UPDATE app_config
    SET value = 'false'::jsonb,
        expires_at = NULL,
        updated_at = NOW()
    WHERE key = 'product_add_unlocked';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_check_product_add_lock ON products;
CREATE TRIGGER trg_check_product_add_lock
  BEFORE INSERT ON products
  FOR EACH ROW EXECUTE FUNCTION check_product_add_lock();

-- Update products INSERT RLS policy as second line of defense
DROP POLICY IF EXISTS "Allow admin to insert products" ON products;
DROP POLICY IF EXISTS "Admins can insert products" ON products;
CREATE POLICY "Admins can insert products when unlocked" ON products
  FOR INSERT TO authenticated
  WITH CHECK (
    (EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND (role = 'admin' OR 'admin' = ANY(roles))
    ))
    AND
    (EXISTS (
      SELECT 1 FROM app_config
      WHERE key = 'product_add_unlocked' AND value = 'true'::jsonb
        AND (expires_at IS NULL OR expires_at >= NOW())
    ))
  );

